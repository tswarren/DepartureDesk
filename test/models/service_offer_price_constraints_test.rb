require "test_helper"

class ServiceOfferPriceConstraintsTest < ActiveSupport::TestCase
  setup do
    @agency = agencies(:harbor)
    @actor = agency_users(:harbor_staff)
    @departure = create_capacity_departure(@agency, name: "Price Constraint Departure")
    @offer = CreateServiceOfferWithExplicitBasis.new(
      agency: @agency, actor: @actor, departure: @departure, idempotency_key: SecureRandom.uuid,
      attributes: { client_title: "Constraint offer", fulfillment_basis: "on_request" }
    ).call.record
    @version = @offer.editable_draft_version
    @definition = create_definition
  end

  test "price tables have uuidv7 defaults and no independently_sellable" do
    connection = ActiveRecord::Base.connection
    %w[service_offer_price_definitions service_offer_price_components service_offer_price_component_bases].each do |table|
      columns = connection.columns(table).index_by(&:name)
      assert_equal "uuidv7()", columns.fetch("id").default_function
      assert_equal "uuid", columns.fetch("agency_id").sql_type
    end
    assert_not_includes connection.columns("service_offer_price_definitions").map(&:name), "independently_sellable"
    assert_not_includes connection.columns("service_offer_price_components").map(&:name), "lock_version"
  end

  test "direct SQL rejects percentage amount and included-tax base" do
    error = assert_raises(ActiveRecord::StatementInvalid) do
      ServiceOfferPriceComponent.transaction(requires_new: true) do
        insert_component(@definition, calculation_kind: "percentage", amount_minor_units: 500, rate: 0.1, percentage_treatment: "additive", quantity_basis: nil)
      end
    end
    assert_match(/kind_shape|check constraint/i, error.message)

    base = insert_component(@definition, label: "Fare", calculation_kind: "fixed", amount_minor_units: 10_000, quantity_basis: "service_instances")
    tax = insert_component(
      @definition, label: "Included", client_role: "tax_fee", calculation_kind: "percentage",
      amount_minor_units: nil, rate: 0.1, percentage_treatment: "included", quantity_basis: nil, position: 2
    )
    later = insert_component(
      @definition, label: "Later", client_role: "named_surcharge", calculation_kind: "percentage",
      amount_minor_units: nil, rate: 0.05, percentage_treatment: "additive", quantity_basis: nil, position: 3
    )
    error = assert_raises(ActiveRecord::StatementInvalid) do
      ServiceOfferPriceComponentBase.transaction(requires_new: true) do
        insert_base(later, tax)
      end
    end
    assert_match(/included-tax/i, error.message)

    assert_nothing_raised { insert_base(tax, base) }
  end

  test "direct SQL rejects owner change and non-draft mutation" do
    component = insert_component(@definition, calculation_kind: "fixed", amount_minor_units: 1_000, quantity_basis: "service_instances")
    error = assert_raises(ActiveRecord::StatementInvalid) do
      ServiceOfferPriceComponent.transaction(requires_new: true) do
        ActiveRecord::Base.connection.execute(
          ActiveRecord::Base.sanitize_sql_array([
            "UPDATE service_offer_price_components SET agency_id = ? WHERE id = ?",
            agencies(:cove).id, component.id
          ])
        )
      end
    end
    assert_match(/owner is immutable/i, error.message)

    DiscardServiceOfferDraft.new(
      agency: @agency, actor: @actor, offer: @offer, reason: "Freeze price",
      offer_lock_version: @offer.lock_version, version_lock_version: @version.lock_version
    ).call
    error = assert_raises(ActiveRecord::StatementInvalid) do
      ServiceOfferPriceComponent.transaction(requires_new: true) do
        component.update_column(:label, "Mutated")
      end
    end
    assert_match(/immutable after leaving draft/i, error.message)
  end

  test "zero-price definitions cannot contain components" do
    @definition.update!(mode: "zero_price", zero_price_reason: "Complimentary")
    error = assert_raises(ActiveRecord::StatementInvalid) do
      ServiceOfferPriceComponent.transaction(requires_new: true) do
        insert_component(@definition, calculation_kind: "fixed", amount_minor_units: 1, quantity_basis: "service_instances")
      end
    end
    assert_match(/zero-price/i, error.message)
  end

  test "direct SQL rejects later position or included treatment on a linked component" do
    fare = insert_component(@definition, label: "Fare", calculation_kind: "fixed", amount_minor_units: 10_000, quantity_basis: "service_instances")
    tax = insert_component(
      @definition, label: "Tax", client_role: "tax_fee", calculation_kind: "percentage",
      amount_minor_units: nil, rate: 0.1, percentage_treatment: "additive", quantity_basis: nil, position: 2
    )
    later = insert_component(
      @definition, label: "Later", client_role: "named_surcharge", calculation_kind: "percentage",
      amount_minor_units: nil, rate: 0.05, percentage_treatment: "additive", quantity_basis: nil, position: 3
    )
    insert_base(tax, fare)
    insert_base(later, tax)

    error = assert_raises(ActiveRecord::StatementInvalid) do
      ServiceOfferPriceComponent.transaction(requires_new: true) do
        ActiveRecord::Base.connection.execute(
          ActiveRecord::Base.sanitize_sql_array([
            "UPDATE service_offer_price_components SET position = 4 WHERE id = ?",
            fare.id
          ])
        )
      end
    end
    assert_match(/earlier component/i, error.message)

    error = assert_raises(ActiveRecord::StatementInvalid) do
      ServiceOfferPriceComponent.transaction(requires_new: true) do
        ActiveRecord::Base.connection.execute(
          ActiveRecord::Base.sanitize_sql_array([
            "UPDATE service_offer_price_components SET percentage_treatment = 'included' WHERE id = ?",
            tax.id
          ])
        )
      end
    end
    assert_match(/included-tax/i, error.message)
  end

  private

  def create_definition
    @version.create_price_definition!(
      agency: @agency, departure: @departure, service_offer: @offer,
      currency: "USD", mode: "calculated"
    )
  end

  def insert_component(definition, **attrs)
    now = Time.current
    row = {
      id: SecureRandom.uuid_v7,
      agency_id: @agency.id,
      departure_id: @departure.id,
      service_offer_id: @offer.id,
      service_offer_version_id: definition.service_offer_version_id,
      service_offer_price_definition_id: definition.id,
      label: attrs.delete(:label) || "Component",
      client_role: attrs.delete(:client_role) || "base_price",
      calculation_kind: attrs[:calculation_kind] || "unit_rate",
      amount_minor_units: attrs[:amount_minor_units],
      rate: attrs[:rate],
      quantity_basis: attrs.key?(:quantity_basis) ? attrs[:quantity_basis] : "persons",
      percentage_treatment: attrs[:percentage_treatment],
      position: attrs.delete(:position) || (definition.service_offer_price_components.maximum(:position).to_i + 1),
      created_at: now,
      updated_at: now
    }
    ServiceOfferPriceComponent.insert!(row)
    ServiceOfferPriceComponent.find(row[:id])
  end

  def insert_base(component, base)
    now = Time.current
    row = {
      id: SecureRandom.uuid_v7,
      agency_id: @agency.id,
      departure_id: @departure.id,
      service_offer_id: @offer.id,
      service_offer_version_id: component.service_offer_version_id,
      service_offer_price_definition_id: component.service_offer_price_definition_id,
      service_offer_price_component_id: component.id,
      base_component_id: base.id,
      direction: "add",
      position: 1,
      created_at: now,
      updated_at: now
    }
    ServiceOfferPriceComponentBase.insert!(row)
    ServiceOfferPriceComponentBase.find(row[:id])
  end
end
