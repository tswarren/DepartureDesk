require "test_helper"

class ServiceOfferConstraintsTest < ActiveSupport::TestCase
  setup do
    @agency = agencies(:harbor)
    @other_agency = agencies(:cove)
    @actor = agency_users(:harbor_admin)
    @departure = @agency.departures.create!(
      name: "Harbor M4A Departure",
      starts_on: Date.new(2026, 6, 1),
      ends_on: Date.new(2026, 6, 8),
      time_zone: "America/New_York",
      operating_currency: "USD",
      status: "draft"
    )
    @other_departure = create_capacity_departure(@other_agency, name: "Cove M4A Departure")
    @contractor = create_capacity_supplier(@agency, "Harbor Contractor")
    @graph = create_capacity_graph(
      agency: @agency, departure: @departure, contractor: @contractor, provider: @contractor, prefix: "M4A"
    )
  end

  test "M4A tables have UUIDv7 defaults ownership and lock columns" do
    connection = ActiveRecord::Base.connection
    %w[service_offers service_offer_versions service_offer_definitions service_offer_source_bindings].each do |table|
      columns = connection.columns(table).index_by(&:name)
      assert_equal "uuidv7()", columns.fetch("id").default_function
      assert_equal "uuid", columns.fetch("agency_id").sql_type
      assert_equal "uuid", columns.fetch("departure_id").sql_type
    end

    assert_includes connection.columns("service_offers").map(&:name), "lock_version"
    assert_includes connection.columns("service_offer_versions").map(&:name), "lock_version"
    assert_not_includes connection.columns("service_offers").map(&:name), "independently_sellable"
    assert_not_includes connection.columns("service_offer_versions").map(&:name), "copied_from_id"
  end

  test "same-agency departure pairing is enforced" do
    assert_raises(ActiveRecord::InvalidForeignKey) do
      ServiceOffer.transaction(requires_new: true) do
        ServiceOffer.insert!(offer_row(departure_id: @other_departure.id))
      end
    end
  end

  test "pool without occurrence or resource is rejected by direct SQL" do
    offer, version = create_offer_graph
    pair = classify_capacity_graph_pair(@graph)
    pool = CapacityPool.create!(
      agency: @agency, departure: @departure,
      supplier_arrangement: @graph[:arrangement],
      arrangement_item: @graph[:item],
      service_occurrence: @graph[:occurrence],
      supplier_resource: @graph[:resource],
      supplying_supplier: @contractor,
      inventory_mode: "block",
      measurement_basis: "resource_units",
      effective_time_zone: "America/New_York"
    )
    pool_definition = CapacityPoolDefinition.create!(
      agency: @agency, departure: @departure,
      supplier_arrangement: @graph[:arrangement],
      supplier_arrangement_version: @graph[:version],
      arrangement_item: @graph[:item],
      service_occurrence: @graph[:occurrence],
      supplier_resource: @graph[:resource],
      capacity_pair_definition: pair,
      capacity_pool: pool,
      label: "M4A pool",
      normalized_label: "m4a pool",
      unit_label: "cabins",
      proposed_opening_quantity: 8,
      evidence_kind: "contract",
      evidence_on: Date.new(2026, 5, 1),
      evidence_reference_note: "Block",
      override: false,
      position: 1
    )

    error = assert_raises(ActiveRecord::StatementInvalid) do
      ServiceOfferSourceBinding.transaction(requires_new: true) do
        ServiceOfferSourceBinding.insert!(
          binding_row(offer, version, @graph).merge(
            capacity_pool_id: pool.id,
            capacity_pool_definition_id: pool_definition.id,
            service_occurrence_id: nil,
            service_occurrence_definition_id: nil,
            supplier_resource_id: nil,
            supplier_resource_definition_id: nil
          )
        )
      end
    end
    assert_match(/pool requires occurrence and resource|check constraint/i, error.message)
  end

  test "direct SQL rejects a resource outside the bound item" do
    offer, version = create_offer_graph
    other = create_capacity_graph(
      agency: @agency, departure: @departure, contractor: @contractor, provider: @contractor, prefix: "Other"
    )

    error = assert_raises(ActiveRecord::StatementInvalid) do
      ServiceOfferSourceBinding.transaction(requires_new: true) do
        ServiceOfferSourceBinding.insert!(
          binding_row(offer, version, @graph).merge(
            supplier_resource_id: other[:resource].id,
            supplier_resource_definition_id: other[:resource_definition].id
          )
        )
      end
    end
    assert_match(/resource is not in the bound item|foreign key|not present in table/i, error.message)
  end

  test "item plus resource without occurrence is allowed" do
    offer, version = create_offer_graph
    assert_nothing_raised do
      ServiceOfferSourceBinding.insert!(
        binding_row(offer, version, @graph).merge(
          service_occurrence_id: nil,
          service_occurrence_definition_id: nil,
          capacity_pool_id: nil,
          capacity_pool_definition_id: nil
        )
      )
    end
  end

  test "discard freezes definitions retains the version number and allows the next number" do
    offer = CreateServiceOfferFromSource.new(
      agency: @agency, actor: @actor, departure: @departure,
      idempotency_key: SecureRandom.uuid,
      attributes: source_attrs(@graph).merge(client_title: "O1 Cabin")
    ).call.record
    version = offer.editable_draft_version
    DiscardServiceOfferDraft.new(
      agency: @agency, actor: @actor, offer: offer, reason: "Not selling",
      offer_lock_version: offer.lock_version, version_lock_version: version.lock_version
    ).call
    version.reload
    assert version.abandoned?
    assert_equal 1, version.version_number
    assert_not_nil version.abandoned_at
    assert_equal "Not selling", version.abandoned_reason

    error = assert_raises(ActiveRecord::StatementInvalid) do
      ServiceOfferDefinition.transaction(requires_new: true) do
        version.definition.update_column(:client_title, "Mutated")
      end
    end
    assert_match(/immutable after leaving draft/i, error.message)

    successor = offer.versions.create!(
      agency: @agency, departure: @departure, version_number: 2, status: "draft"
    )
    assert_equal 2, successor.version_number
    assert_raises(ActiveRecord::RecordNotUnique) do
      offer.versions.create!(agency: @agency, departure: @departure, version_number: 1, status: "draft")
    end
  end

  test "referenced M3 history cannot be deleted while bound" do
    offer = CreateServiceOfferFromSource.new(
      agency: @agency, actor: @actor, departure: @departure,
      idempotency_key: SecureRandom.uuid,
      attributes: source_attrs(@graph).merge(client_title: "Bound cabin")
    ).call.record
    assert_equal 1, offer.editable_draft_version.source_bindings.count

    assert_raises(ActiveRecord::DeleteRestrictionError) { @graph[:item].destroy }
    assert_raises(ActiveRecord::DeleteRestrictionError) { @graph[:version].destroy }
  end

  private

  def create_offer_graph
    offer = ServiceOffer.create!(agency: @agency, departure: @departure, name: "Draft offer")
    version = offer.versions.create!(
      agency: @agency, departure: @departure, version_number: 1, status: "draft"
    )
    version.create_definition!(
      agency: @agency, departure: @departure, service_offer: offer,
      client_title: "Draft title", fulfillment_basis: "m3_backed"
    )
    [ offer, version ]
  end

  def source_attrs(graph)
    {
      supplier_arrangement_id: graph[:arrangement].id,
      supplier_arrangement_version_id: graph[:version].id,
      arrangement_item_id: graph[:item].id,
      service_occurrence_id: graph[:occurrence].id,
      supplier_resource_id: graph[:resource].id
    }
  end

  def offer_row(**attrs)
    {
      id: SecureRandom.uuid_v7,
      agency_id: @agency.id,
      departure_id: @departure.id,
      name: "Inserted offer",
      lock_version: 0,
      created_at: Time.current,
      updated_at: Time.current
    }.merge(attrs)
  end

  def binding_row(offer, version, graph)
    {
      id: SecureRandom.uuid_v7,
      agency_id: @agency.id,
      departure_id: @departure.id,
      service_offer_id: offer.id,
      service_offer_version_id: version.id,
      membership_kind: "required",
      position: 1,
      supplier_arrangement_id: graph[:arrangement].id,
      arrangement_item_id: graph[:item].id,
      service_occurrence_id: graph[:occurrence].id,
      supplier_resource_id: graph[:resource].id,
      capacity_pool_id: nil,
      supplier_arrangement_version_id: graph[:version].id,
      arrangement_item_definition_id: graph[:item_definition].id,
      service_occurrence_definition_id: graph[:occurrence_definition].id,
      supplier_resource_definition_id: graph[:resource_definition].id,
      capacity_pool_definition_id: nil,
      depend_on_item_name: false,
      depend_on_item_description: false,
      depend_on_occurrence_name: false,
      depend_on_occurrence_description: false,
      depend_on_resource_name: false,
      depend_on_resource_description: false,
      depend_on_pool_label: false,
      depend_on_pool_unit_label: false,
      client_title_provenance: "source_name",
      client_description_provenance: "none",
      created_at: Time.current,
      updated_at: Time.current
    }
  end
end
