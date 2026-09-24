# frozen_string_literal: true

require "test_helper"

class CruiseClientTermScheduleTest < ActiveSupport::TestCase
  setup do
    @agency = agencies(:harbor)
    @actor = agency_users(:harbor_staff)
    @departure = create_capacity_departure(@agency, name: "Smith Family Cruise")
    @contractor = create_capacity_supplier(@agency, "Celebrity Cruises")
    @provider = create_capacity_supplier(@agency, "Celebrity Ship Ops")
    @contact = @contractor.contacts.create!(
      agency: @agency, first_name: "Group", last_name: "Desk", status: "active"
    )
  end

  test "double-only occupancy enables first and second and saves those cells in place" do
    arrangement, version, item, ocean = cruise_with_cabins("O1" => "Prime Oceanview")
    confirm_occupancy(arrangement, version, ocean, double: 1)
    offer = connect_new(arrangement, version, item, [ ocean.id ]).record
    option = offer.editable_draft_version.choice_options.sole
    bands = CompileCruiseClientTermBandSet.new(
      agency: @agency, arrangement_version: version.reload, resource: ocean
    ).call

    assert_equal %w[first second], bands.enabled
    assert_not bands.advanced?

    created = save_terms(offer, option, version, [
      cell("cruise_fare", "first", "1931.00"),
      cell("cruise_fare", "second", "1931.00")
    ])
    component = created.record.service_offer_price_components.find_by!(occupancy_position_key: "first")
    assert_equal "cruise_fare", component.cruise_client_term_row_key
    assert_equal 193_100, component.amount_minor_units

    updated = UpdateCruiseClientTermSchedule.new(
      agency: @agency, actor: @actor, offer: offer,
      attributes: {
        choice_option_id: option.id,
        version_lock_version: offer.editable_draft_version.reload.lock_version,
        cells: [
          cell("cruise_fare", "first", "2000.00"),
          cell("cruise_fare", "second", "1931.00")
        ]
      }
    ).call
    assert_equal component.id, updated.record.service_offer_price_components.find_by!(occupancy_position_key: "first").id
    assert_equal 200_000, updated.record.service_offer_price_components.find_by!(occupancy_position_key: "first").amount_minor_units
  end

  test "create retry replays and a different payload conflicts" do
    arrangement, version, item, ocean = cruise_with_cabins("O1" => "Prime Oceanview")
    confirm_occupancy(arrangement, version, ocean, double: 1)
    offer = connect_new(arrangement, version, item, [ ocean.id ]).record
    option = offer.editable_draft_version.choice_options.sole
    key = SecureRandom.uuid
    first = save_terms(offer, option, version, [ cell("cruise_fare", "first", "10.00") ], key: key)
    second = save_terms(offer, option, version, [ cell("cruise_fare", "first", "10.00") ], key: key)
    assert_equal :replayed, second.status
    assert_equal first.record.id, second.record.id

    error = assert_raises(AgencyCommand::Error) do
      save_terms(offer, option, version, [ cell("cruise_fare", "first", "11.00") ], key: key)
    end
    assert_equal :conflict, error.code
  end

  test "supplier copy proposes enabled cells and recopy keeps the component" do
    arrangement, version, item, ocean = cruise_with_cabins("O1" => "Prime Oceanview")
    confirm_occupancy(arrangement, version, ocean, double: 1)
    CreateCruiseSupplierRateSchedule.new(
      agency: @agency, actor: @actor, arrangement: arrangement, resource: ocean,
      terms: {
        first_second_fare: "1624.00", additional_fare: "406.00", single_supplement: "1624.00",
        nccf: "320.00", first_second_discount: "150.00", additional_discount: "37.50", taxes_fees: "137.00"
      },
      commission: { method: "not_provided" }, stage: "estimate",
      version_lock_version: version.reload.lock_version, idempotency_key: SecureRandom.uuid
    ).call
    offer = connect_new(arrangement, version.reload, item, [ ocean.id ]).record
    option = offer.editable_draft_version.choice_options.sole
    proposal = ProposeCruiseSupplierTermCopy.new(
      agency: @agency, arrangement_version: version.reload, resource: ocean, enabled_bands: %w[first second]
    ).call

    fare_cells = proposal.cells.select { |cell| cell.row_key == "cruise_fare" }
    assert_equal %w[first second], fare_cells.map(&:band).sort
    assert_equal 1, fare_cells.map(&:source_id).uniq.size
    assert fare_cells.all?(&:expands)
    assert_not proposal.cells.any? { |cell| cell.band == "single" || cell.band == "additional" }
    assert proposal.unsupported.any? { |reason| reason.match?(/not copied|does not cover/) }

    created = save_terms(offer, option, version, proposal.cells.map { |cell|
      cell(cell.row_key, cell.band, cell.amount).merge(supplier_cost_component_id: cell.source_id)
    }, arrangement_lock_version: version.lock_version)
    component = created.record.service_offer_price_components.find_by!(cruise_client_term_row_key: "cruise_fare", occupancy_position_key: "first")
    fingerprint = component.copied_from_supplier_cost_component_fingerprint
    source = SupplierCostComponent.find(component.copied_from_supplier_cost_component_id)
    source.update!(amount_minor_units: source.amount_minor_units + 100)
    assert_equal "changed", CompareSupplierCostCopyProvenance.call(
      component: component, pinned_version_id: version.id, resource_id: ocean.id
    )

    kept = update_terms(offer, option, proposal.cells.map { |cell|
      cell(cell.row_key, cell.band, cell.amount).merge(supplier_cost_component_id: cell.source_id, recopy: false)
    }, arrangement_lock_version: version.reload.lock_version)
    kept_component = kept.record.service_offer_price_components.find(component.id)
    assert_equal fingerprint, kept_component.copied_from_supplier_cost_component_fingerprint

    recopied = update_terms(offer, option, proposal.cells.map { |cell|
      attrs = cell(cell.row_key, cell.band, cell.row_key == "cruise_fare" && cell.band == "first" ? "1724.00" : cell.amount)
      attrs.merge(supplier_cost_component_id: cell.source_id, recopy: cell.row_key == "cruise_fare" && cell.band == "first")
    }, arrangement_lock_version: version.reload.lock_version)
    recopied_component = recopied.record.service_offer_price_components.find(component.id)
    assert_equal 172_400, recopied_component.amount_minor_units
    assert_not_equal fingerprint, recopied_component.copied_from_supplier_cost_component_fingerprint

    cleared = update_terms(offer, option, proposal.cells.map { |cell|
      attrs = cell(cell.row_key, cell.band, cell.row_key == "cruise_fare" && cell.band == "first" ? "1724.00" : cell.amount)
      attrs.merge(
        supplier_cost_component_id: cell.source_id,
        clear_provenance: cell.row_key == "cruise_fare" && cell.band == "first"
      )
    }, arrangement_lock_version: version.reload.lock_version)
    cleared_component = cleared.record.service_offer_price_components.find(component.id)
    assert_nil cleared_component.copied_from_supplier_cost_component_id
    assert_equal 172_400, cleared_component.amount_minor_units
  end

  test "a second category save leaves the first category components in place" do
    arrangement, version, item, ocean, inside = cruise_with_cabins("O1" => "Prime Oceanview", "I1" => "Inside")
    confirm_occupancy(arrangement, version, ocean, double: 1)
    confirm_occupancy(arrangement, version, inside, double: 1)
    offer = connect_new(arrangement, version, item, [ ocean.id, inside.id ]).record
    options = offer.editable_draft_version.choice_options.order(:position).to_a
    first = save_terms(offer, options[0], version, [ cell("cruise_fare", "first", "10.00"), cell("cruise_fare", "second", "10.00") ])
    ocean_ids = first.record.service_offer_price_components.order(:id).pluck(:id)
    update_terms(offer, options[1], [ cell("cruise_fare", "first", "20.00"), cell("cruise_fare", "second", "20.00") ])
    assert_equal ocean_ids, first.record.reload.service_offer_price_components.where(client_rate_category_key: options[0].client_rate_category_key).order(:id).pluck(:id)
  end

  test "removing a supplier profile keeps client cells and reports the unsupported band" do
    arrangement, version, item, ocean = cruise_with_cabins("O1" => "Prime Oceanview")
    confirm_occupancy(arrangement, version, ocean, single: 1, double: 1)
    offer = connect_new(arrangement, version.reload, item, [ ocean.id ]).record
    option = offer.editable_draft_version.choice_options.sole
    save_terms(offer, option, version, [
      cell("cruise_fare", "single", "10.00"),
      cell("cruise_fare", "first", "20.00"),
      cell("cruise_fare", "second", "20.00")
    ])
    SetCruiseSupplierOccupancyPlan.new(
      agency: @agency, actor: @actor, arrangement: arrangement, resource: ocean,
      expected_cabins: { double: 1 }, version_lock_version: version.reload.lock_version
    ).call
    component_count = offer.editable_draft_version.price_definition.service_offer_price_components.count
    assert_equal 3, component_count
    findings = EvaluateDepartureBuilderReadiness.new(agency: @agency, departure: @departure).call.findings
    assert findings.any? { |finding| finding.code == :cruise_client_band_no_longer_supported }
    assert_not findings.any? { |finding| finding.code == :cruise_client_band_no_longer_supported && finding.applicable_to?(:publication) }
  end

  test "a category base price waives a null option surcharge" do
    arrangement, version, item, ocean = cruise_with_cabins("O1" => "Prime Oceanview")
    confirm_occupancy(arrangement, version, ocean, double: 1)
    offer = connect_new(arrangement, version, item, [ ocean.id ]).record
    option = offer.editable_draft_version.choice_options.sole
    before = EvaluateServiceOfferPublicationReadiness.new(agency: @agency, version: offer.editable_draft_version).call
    assert before.issues.any? { |issue| issue.message == "Enter the category price for #{option.name}." }
    assert_not before.issues.any? { |issue| issue.message.include?("included price (0) or surcharge") }

    save_terms(offer, option, version, [ cell("cruise_fare", "first", "1931.00"), cell("cruise_fare", "second", "1931.00") ])
    decision = CruiseCategoryOptionPrice.call(option: option.reload, version: offer.editable_draft_version)
    assert_equal :waived, decision.status
    after = EvaluateServiceOfferPublicationReadiness.new(agency: @agency, version: offer.editable_draft_version).call
    assert_not after.issues.any? { |issue| issue.message.include?("category price") || issue.message.include?("included price (0) or surcharge") }
  end

  test "double review includes the stored rate category and omits single" do
    arrangement, version, item, ocean = cruise_with_cabins("O1" => "Prime Oceanview")
    confirm_occupancy(arrangement, version, ocean, double: 1)
    offer = connect_new(arrangement, version, item, [ ocean.id ]).record
    option = offer.editable_draft_version.choice_options.sole
    save_terms(offer, option, version, [ cell("cruise_fare", "first", "10.00"), cell("cruise_fare", "second", "12.00") ])
    review = CompileCruiseScenarioReview.new(
      agency: @agency, actor: @actor, offer: offer, version: offer.editable_draft_version, option: option
    ).call
    single = review.find { |row| row[:name] == "single" }
    double = review.find { |row| row[:name] == "double" }
    assert single[:omitted]
    assert_not double[:pending]
    assert double[:price].complete
    assert_equal 2_200, double[:price].amount_minor_units
    assert double[:capacity][:text].include?("not promised inventory")
  end

  test "a supplier term from another cabin is rejected without writes" do
    arrangement, version, item, ocean, inside = cruise_with_cabins("O1" => "Prime Oceanview", "I1" => "Inside")
    confirm_occupancy(arrangement, version, ocean, double: 1)
    confirm_occupancy(arrangement, version, inside, double: 1)
    CreateCruiseSupplierRateSchedule.new(
      agency: @agency, actor: @actor, arrangement: arrangement, resource: inside,
      terms: { first_second_fare: "100.00", nccf: "10.00", taxes_fees: "5.00" },
      commission: { method: "not_provided" }, stage: "estimate",
      version_lock_version: version.reload.lock_version, idempotency_key: SecureRandom.uuid
    ).call
    offer = connect_new(arrangement, version.reload, item, [ ocean.id, inside.id ]).record
    ocean_option = offer.editable_draft_version.choice_options.find { |option| option.name.include?("O1") }
    inside_source = SupplierCostComponent.joins(supplier_cost_definition: :supplier_cost_source)
      .find_by!(supplier_cost_sources: { supplier_resource_id: inside.id })
    assert_no_difference "ServiceOfferPriceComponent.count" do
      error = assert_raises(AgencyCommand::Error) do
        save_terms(offer, ocean_option, version, [
          cell("cruise_fare", "first", "10.00").merge(supplier_cost_component_id: inside_source.id)
        ], arrangement_lock_version: version.reload.lock_version)
      end
      assert_equal :not_found, error.code
    end
  end

  test "unsafe client graphs stay unchanged" do
    arrangement, version, item, ocean, inside = cruise_with_cabins("O1" => "Prime Oceanview", "I1" => "Inside")
    confirm_occupancy(arrangement, version, ocean, double: 1)
    confirm_occupancy(arrangement, version, inside, double: 1)
    offer = connect_new(arrangement, version, item, [ ocean.id, inside.id ]).record
    options = offer.editable_draft_version.choice_options.order(:position).to_a
    save_terms(offer, options[0], version, [ cell("cruise_fare", "first", "10.00"), cell("cruise_fare", "second", "10.00") ])
    save_terms(offer, options[1], version, [ cell("cruise_fare", "first", "20.00"), cell("cruise_fare", "second", "20.00") ])
    definition = offer.editable_draft_version.price_definition
    first = definition.service_offer_price_components.find_by!(client_rate_category_key: options[0].client_rate_category_key, occupancy_position_key: "first")
    second_category = definition.service_offer_price_components.find_by!(client_rate_category_key: options[1].client_rate_category_key, occupancy_position_key: "first")

    assert_graph_unchanged(offer, options[0], first) { first.update_columns(client_rate_category_key: nil) }
    first.update_columns(client_rate_category_key: options[0].client_rate_category_key)
    assert_graph_unchanged(offer, options[0], first) { first.update_columns(client_rate_category_key: "adult") }
    first.update_columns(client_rate_category_key: options[0].client_rate_category_key)
    assert_graph_unchanged(offer, options[0], first) { first.update_columns(cruise_client_term_row_key: nil) }
    first.update_columns(cruise_client_term_row_key: "cruise_fare")
    assert_graph_unchanged(offer, options[0], first) { first.update_columns(occupancy_position_key: "child") }
    first.update_columns(occupancy_position_key: "first")

    percentage = definition.service_offer_price_components.create!(
      agency: @agency, departure: @departure, service_offer: offer, service_offer_version: offer.editable_draft_version,
      label: "Percent", client_role: "named_surcharge", calculation_kind: "percentage", rate: 0.1,
      percentage_treatment: "additive", client_rate_category_key: options[0].client_rate_category_key,
      occupancy_position_key: "first", cruise_client_term_row_key: CruiseClientTermRows.mint_custom_key, position: 50
    )
    percentage.service_offer_price_component_bases.create!(
      agency: @agency, departure: @departure, service_offer: offer, service_offer_version: offer.editable_draft_version,
      service_offer_price_definition: definition, base_component: second_category, direction: "add", position: 1
    )
    before = definition.service_offer_price_components.count
    error = assert_raises(AgencyCommand::Error) { update_terms(offer, options[0], [ cell("cruise_fare", "first", "11.00"), cell("cruise_fare", "second", "10.00") ]) }
    assert_equal :invalid, error.code
    assert_equal before, definition.reload.service_offer_price_components.count
    assert_equal 10_00, first.reload.amount_minor_units
  end

  test "a typed cell with the wrong role calculation or quantity stays advanced" do
    arrangement, version, item, ocean = cruise_with_cabins("O1" => "Prime Oceanview")
    confirm_occupancy(arrangement, version, ocean, double: 1)
    offer = connect_new(arrangement, version, item, [ ocean.id ]).record
    option = offer.editable_draft_version.choice_options.sole
    save_terms(offer, option, version, [ cell("cruise_fare", "first", "10.00"), cell("cruise_fare", "second", "10.00") ])
    first = offer.editable_draft_version.price_definition.service_offer_price_components.find_by!(occupancy_position_key: "first")

    assert_graph_unchanged(offer, option, first) { first.update_columns(client_role: "named_discount") }
    first.update_columns(client_role: "base_price")
    assert_graph_unchanged(offer, option, first) { first.update_columns(calculation_kind: "fixed", quantity_basis: "service_instances") }
    first.update_columns(calculation_kind: "unit_rate", quantity_basis: "occupancy_positions")
    assert_graph_unchanged(offer, option, first) { first.update_columns(quantity_basis: "persons") }
  end

  test "a same cabin source that does not cover the cell is rejected" do
    arrangement, version, item, ocean = cruise_with_cabins("O1" => "Prime Oceanview")
    confirm_occupancy(arrangement, version, ocean, double: 1)
    CreateCruiseSupplierRateSchedule.new(
      agency: @agency, actor: @actor, arrangement: arrangement, resource: ocean,
      terms: { first_second_fare: "1624.00", nccf: "320.00", taxes_fees: "137.00" },
      commission: { method: "not_provided" }, stage: "estimate",
      version_lock_version: version.reload.lock_version, idempotency_key: SecureRandom.uuid
    ).call
    offer = connect_new(arrangement, version.reload, item, [ ocean.id ]).record
    option = offer.editable_draft_version.choice_options.sole
    nccf = SupplierCostComponent.joins(supplier_cost_definition: :supplier_cost_source)
      .where(supplier_cost_sources: { supplier_resource_id: ocean.id })
      .find { |component| component.label.to_s.downcase.include?("nccf") || component.label.to_s.downcase.include?("non-commission") }
    assert nccf
    assert_no_difference "ServiceOfferPriceComponent.count" do
      error = assert_raises(AgencyCommand::Error) do
        save_terms(offer, option, version, [
          cell("cruise_fare", "first", "10.00").merge(supplier_cost_component_id: nccf.id)
        ], arrangement_lock_version: version.reload.lock_version)
      end
      assert_equal :invalid, error.code
    end
  end

  test "an ordinary keyed choice with a null effect stays incomplete" do
    arrangement, version, item, ocean = cruise_with_cabins("O1" => "Prime Oceanview")
    confirm_occupancy(arrangement, version, ocean, double: 1)
    offer = connect_new(arrangement, version, item, [ ocean.id ]).record
    option = offer.editable_draft_version.choice_options.sole
    save_terms(offer, option, version, [ cell("cruise_fare", "first", "10.00"), cell("cruise_fare", "second", "10.00") ])
    option.update_columns(client_rate_category_key: "adult")
    offer.editable_draft_version.price_definition.service_offer_price_components.update_all(client_rate_category_key: "adult")
    decision = CruiseCategoryOptionPrice.call(option: option.reload, version: offer.editable_draft_version)
    assert_equal :incomplete, decision.status
    assert_equal :ordinary_option, decision.reason
  end

  test "a copy snapshot rejects extra mapping keys" do
    snapshot = SupplierCostComponentCopyFingerprint.snapshot(
      mapped_client_role: "base_price", mapped_calculation_kind: "unit_rate",
      mapped_quantity_basis: "occupancy_positions", target_occupancy_position: "first"
    )
    assert SupplierCostComponentCopyFingerprint.valid_snapshot?(snapshot)
    assert_not SupplierCostComponentCopyFingerprint.valid_snapshot?(snapshot.merge("extra" => "1"))
  end

  test "maximum occupancy without a triple profile does not enable additional" do
    arrangement, version, _item, ocean = cruise_with_cabins("O1" => "Prime Oceanview")
    confirm_occupancy(arrangement, version, ocean, double: 1)
    bands = CompileCruiseClientTermBandSet.new(agency: @agency, arrangement_version: version.reload, resource: ocean).call
    assert_not_includes bands.enabled, "additional"
  end

  private

  def assert_graph_unchanged(offer, option, component)
    before = component.amount_minor_units
    yield
    error = assert_raises(AgencyCommand::Error) do
      update_terms(offer, option, [ cell("cruise_fare", "first", "99.00"), cell("cruise_fare", "second", "10.00") ])
    end
    assert_equal :invalid, error.code
    assert_equal before, component.reload.amount_minor_units
  end

  def cell(row_key, band, amount)
    { row_key: row_key, band: band, amount: amount }
  end

  def save_terms(offer, option, version, cells, key: SecureRandom.uuid, arrangement_lock_version: nil)
    CreateCruiseClientTermSchedule.new(
      agency: @agency, actor: @actor, offer: offer, idempotency_key: key,
      attributes: {
        choice_option_id: option.id,
        version_lock_version: offer.editable_draft_version.lock_version,
        arrangement_lock_version: arrangement_lock_version,
        cells: cells
      }
    ).call
  end

  def update_terms(offer, option, cells, arrangement_lock_version: nil)
    UpdateCruiseClientTermSchedule.new(
      agency: @agency, actor: @actor, offer: offer,
      attributes: {
        choice_option_id: option.id,
        version_lock_version: offer.editable_draft_version.reload.lock_version,
        arrangement_lock_version: arrangement_lock_version,
        cells: cells
      }
    ).call
  end

  def confirm_occupancy(arrangement, version, resource, counts)
    SetCruiseSupplierOccupancyPlan.new(
      agency: @agency, actor: @actor, arrangement: arrangement, resource: resource,
      expected_cabins: counts, version_lock_version: version.reload.lock_version
    ).call
  end

  def connect_new(arrangement, version, item, resource_ids)
    ConnectCruiseServiceOffer.new(
      agency: @agency, actor: @actor, arrangement: arrangement, idempotency_key: SecureRandom.uuid,
      attributes: {
        mode: "new", title: "Celebrity Beyond sailing",
        supplier_arrangement_version_id: version.id, use_tentative_draft: true,
        arrangement_lock_version: version.reload.lock_version, arrangement_item_id: item.id,
        supplier_resource_ids: resource_ids
      }
    ).call
  end

  def cruise_with_cabins(cabins)
    sailing = CreateCruiseSailingSetup.new(
      agency: @agency, actor: @actor, departure: @departure,
      arrangement_attributes: { name: "Celebrity group agreement", contracting_supplier_id: @contractor.id, supplier_contact_id: @contact.id },
      item_attributes: { name: "Celebrity Beyond", default_service_provider_id: @provider.id },
      occurrence_attributes: { name: "Western Caribbean", starts_on: "2027-11-06", ends_on: "2027-11-13", time_zone: "America/New_York" },
      idempotency_key: SecureRandom.uuid
    ).call
    arrangement = sailing.record.arrangement
    version = arrangement.versions.sole
    item = sailing.record.item
    resources = cabins.map do |code, name|
      CreateCruiseCabinCategorySetup.new(
        agency: @agency, actor: @actor, arrangement: arrangement,
        resource_attributes: { name: name, supplier_code: code, maximum_occupancy: 3 },
        pool_attributes: { inventory_mode: "block", proposed_opening_quantity: 8 },
        version_lock_version: version.reload.lock_version, idempotency_key: SecureRandom.uuid
      ).call.record.resource
    end
    [ arrangement, version.reload, item, *resources ]
  end
end
