require "test_helper"

class ServiceOfferPriceCommandsTest < ActiveSupport::TestCase
  setup do
    @agency = agencies(:harbor)
    @actor = agency_users(:harbor_staff)
    @viewer = agency_users(:harbor_viewer)
    @admin = agency_users(:harbor_admin)
    @office = offices(:harbor_main)
    @departure = create_capacity_departure(@agency, name: "Price Departure")
    @offer = CreateServiceOfferWithExplicitBasis.new(
      agency: @agency, actor: @actor, departure: @departure, idempotency_key: SecureRandom.uuid,
      attributes: { client_title: "Priced cabin", fulfillment_basis: "on_request" }
    ).call.record
  end

  test "simple pattern creates one base price and audits bounded details" do
    version = @offer.editable_draft_version
    result = create_price(@offer, pattern: "per_person", amount: "125.00")
    definition = result.record
    assert_equal :created, result.status
    assert_equal "calculated", definition.mode
    assert_equal "USD", definition.currency
    component = definition.service_offer_price_components.sole
    assert_equal "base_price", component.client_role
    assert_equal "unit_rate", component.calculation_kind
    assert_equal "persons", component.quantity_basis
    assert_equal 12_500, component.amount_minor_units
    event = AuditEvent.find_by!(action: "service_offer.price_created", subject_id: @offer.id)
    assert_equal 1, event.details["component_count"]
    assert_nil event.details["components"]
    assert_nil event.details["scenario"]
    assert_operator @offer.editable_draft_version.reload.lock_version, :>, version.lock_version
  end

  test "keyed create replays before rejecting a stale lock" do
    key = SecureRandom.uuid
    first = CreateServiceOfferPriceDefinition.new(
      agency: @agency, actor: @actor, offer: @offer, idempotency_key: key,
      version_lock_version: @offer.editable_draft_version.lock_version,
      attributes: { pattern: "fixed_per_service", amount: "90.00" }
    ).call
    stale = @offer.editable_draft_version.lock_version - 1
    replay = CreateServiceOfferPriceDefinition.new(
      agency: @agency, actor: @actor, offer: @offer, idempotency_key: key,
      version_lock_version: stale,
      attributes: { pattern: "fixed_per_service", amount: "90.00" }
    ).call
    assert_equal :replayed, replay.status
    assert_equal first.record.id, replay.record.id
  end

  test "two successive price edits from the same version lock conflict" do
    create_price(@offer, pattern: "per_person", amount: "100.00")
    lock = @offer.editable_draft_version.reload.lock_version
    UpdateServiceOfferPriceDefinition.new(
      agency: @agency, actor: @actor, offer: @offer, version_lock_version: lock,
      attributes: { pattern: "per_person", amount: "110.00" }
    ).call
    error = assert_raises(AgencyCommand::Error) do
      UpdateServiceOfferPriceDefinition.new(
        agency: @agency, actor: @actor, offer: @offer, version_lock_version: lock,
        attributes: { pattern: "per_person", amount: "120.00" }
      ).call
    end
    assert_equal :conflict, error.code
    assert_equal 11_000, @offer.editable_draft_version.price_definition.service_offer_price_components.sole.amount_minor_units
  end

  test "update atomically replaces components" do
    create_price(@offer, pattern: "per_person", amount: "100.00")
    UpdateServiceOfferPriceDefinition.new(
      agency: @agency, actor: @actor, offer: @offer,
      version_lock_version: @offer.editable_draft_version.reload.lock_version,
      attributes: {
        components: [
          {
            label: "Cabin fare", client_role: "base_price", calculation_kind: "fixed",
            amount: "200.00", quantity_basis: "service_instances"
          },
          {
            label: "Port tax", client_role: "tax_fee", calculation_kind: "percentage",
            percentage: "10", percentage_treatment: "additive",
            bases: [ { base_position: 1, direction: "add" } ]
          }
        ]
      }
    ).call
    components = @offer.editable_draft_version.price_definition.service_offer_price_components.order(:position)
    assert_equal [ "Cabin fare", "Port tax" ], components.map(&:label)
    assert_equal 1, components.last.service_offer_price_component_bases.count
  end

  test "departed departure rejects create and update but allows remove" do
    create_price(@offer, pattern: "per_person", amount: "80.00")
    depart_current_departure!
    error = assert_raises(AgencyCommand::Error) do
      UpdateServiceOfferPriceDefinition.new(
        agency: @agency, actor: @actor, offer: @offer.reload,
        version_lock_version: @offer.editable_draft_version.lock_version,
        attributes: { pattern: "per_person", amount: "90.00" }
      ).call
    end
    assert_equal :invalid_state, error.code

    RemoveServiceOfferPriceDefinition.new(
      agency: @agency, actor: @actor, offer: @offer.reload,
      version_lock_version: @offer.editable_draft_version.lock_version
    ).call
    assert_nil @offer.editable_draft_version.price_definition
    assert AuditEvent.exists?(action: "service_offer.price_removed", subject_id: @offer.id)
  end

  test "retained price blocks ordinary currency change and correction until removed" do
    create_price(@offer, pattern: "per_person", amount: "80.00")
    error = assert_raises(AgencyCommand::Error) do
      UpdateDeparture.new(
        agency: @agency, actor: @actor, departure: @departure,
        lock_version: @departure.lock_version,
        attributes: @departure.slice(:name, :description, :starts_on, :ends_on, :time_zone).merge(operating_currency: "EUR")
      ).call
    end
    assert_equal :invalid_state, error.code
    assert_match(/Client price/i, error.message)

    depart_current_departure!
    error = assert_raises(AgencyCommand::Error) do
      CorrectDepartureCurrency.new(
        agency: @agency, actor: @admin, departure: @departure.reload,
        operating_currency: "EUR", reason: "Supplier billed EUR",
        lock_version: @departure.lock_version
      ).call
    end
    assert_equal :invalid_state, error.code

    RemoveServiceOfferPriceDefinition.new(
      agency: @agency, actor: @actor, offer: @offer.reload,
      version_lock_version: @offer.editable_draft_version.lock_version
    ).call
    CorrectDepartureCurrency.new(
      agency: @agency, actor: @admin, departure: @departure.reload,
      operating_currency: "EUR", reason: "Supplier billed EUR",
      lock_version: @departure.lock_version
    ).call
    assert_equal "EUR", @departure.reload.operating_currency
  end

  test "viewer cannot mutate price" do
    error = assert_raises(AgencyCommand::Error) do
      CreateServiceOfferPriceDefinition.new(
        agency: @agency, actor: @viewer, offer: @offer, idempotency_key: SecureRandom.uuid,
        version_lock_version: @offer.editable_draft_version.lock_version,
        attributes: { pattern: "per_person", amount: "10.00" }
      ).call
    end
    assert_equal :unauthorized, error.code
  end

  test "kind-specific fields reject a percentage amount" do
    error = assert_raises(AgencyCommand::Error) do
      CreateServiceOfferPriceDefinition.new(
        agency: @agency, actor: @actor, offer: @offer, idempotency_key: SecureRandom.uuid,
        version_lock_version: @offer.editable_draft_version.lock_version,
        attributes: {
          components: [ {
            label: "Tax", client_role: "tax_fee", calculation_kind: "percentage",
            amount: "5.00", percentage: "10", percentage_treatment: "additive",
            bases: [ { base_position: 1 } ]
          } ]
        }
      ).call
    end
    assert_equal :invalid, error.code
  end

  private

  def create_price(offer, pattern:, amount:)
    CreateServiceOfferPriceDefinition.new(
      agency: @agency, actor: @actor, offer: offer, idempotency_key: SecureRandom.uuid,
      version_lock_version: offer.editable_draft_version.lock_version,
      attributes: { pattern: pattern, amount: amount }
    ).call
  end

  def depart_current_departure!
    @departure.update!(
      responsible_office: @office,
      responsible_agency_user: @admin,
      starts_on: Date.new(2026, 6, 1),
      ends_on: Date.new(2026, 6, 8),
      time_zone: "America/New_York",
      operating_currency: "USD"
    )
    ActivateDeparture.new(
      agency: @agency, actor: @admin, departure: @departure, lock_version: @departure.lock_version
    ).call
    MarkDepartureDeparted.new(
      agency: @agency, departure: @departure.reload, actor_kind: :agency_user,
      actor: @admin, lock_version: @departure.lock_version
    ).call
    @departure.reload
  end
end
