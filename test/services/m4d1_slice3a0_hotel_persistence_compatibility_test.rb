require "test_helper"

class M4d1Slice3a0HotelPersistenceCompatibilityTest < ActiveSupport::TestCase
  setup do
    @agency = agencies(:harbor)
    @admin = agency_users(:harbor_admin)
    @office = offices(:harbor_main)
    ensure_supplier_sequence!(@agency)
    @contractor = CreateSupplier.new(
      agency: @agency,
      actor: @admin,
      kind: "organization",
      names: { display_name: "Hilton Fort Lauderdale Marina" },
      categories: [ "lodging" ]
    ).call.record
    @contact = @contractor.contacts.create!(
      agency: @agency,
      first_name: "Harbor",
      last_name: "Contracting",
      status: "active"
    )
    @departure = CreateDeparture.new(
      agency: @agency,
      actor: @admin,
      attributes: {
        name: "Smith Family Reunion",
        starts_on: Date.new(2027, 11, 4),
        ends_on: Date.new(2027, 11, 6),
        time_zone: "America/New_York",
        operating_currency: "USD",
        responsible_office_id: @office.id,
        responsible_agency_user_id: @admin.id
      },
      current_office: @office
    ).call.record
    @arrangement = CreateSupplierArrangement.new(
      agency: @agency,
      actor: @admin,
      departure: @departure,
      idempotency_key: "hilton-arrangement",
      attributes: {
        name: "Pre-cruise hotel stay",
        contracting_supplier_id: @contractor.id,
        supplier_contact_id: @contact.id
      }
    ).call.record
    @version = @arrangement.versions.sole
  end

  test "shipped supplier records store the hilton graph and the typed supplier terms" do
    item = create_item("Pre-cruise hotel stay")
    mark_managed!(item)
    standard = create_resource(item, "Standard")
    deluxe = create_resource(item, "Deluxe")
    stay = create_occurrence(
      item, "Stay",
      starts_on: "2027-11-04", ends_on: "2027-11-06",
      starts_at_local: "15:00", ends_at_local: "12:00",
      time_zone: "America/New_York"
    )
    november_4 = create_occurrence(item, "November 4", starts_on: "2027-11-04", ends_on: "2027-11-04")
    november_5 = create_occurrence(item, "November 5", starts_on: "2027-11-05", ends_on: "2027-11-05")

    classify!(item, stay, standard, "not_applicable")
    classify!(item, stay, deluxe, "not_applicable")
    openings = {
      [ november_4, standard ] => 5,
      [ november_4, deluxe ] => 2,
      [ november_5, standard ] => 10,
      [ november_5, deluxe ] => 5
    }
    openings.each do |pair, quantity|
      configure_pool!(item, pair.first, pair.last, quantity)
    end

    item_definition = @version.arrangement_item_definitions.find_by!(arrangement_item: item)
    assert_equal "managed", item_definition.capacity_management

    stay_definition = definition_for(stay)
    assert_equal Date.new(2027, 11, 4), stay_definition.starts_on
    assert_equal Date.new(2027, 11, 6), stay_definition.ends_on
    assert_equal "America/New_York", stay_definition.time_zone
    assert_equal [ 15, 0 ], [ stay_definition.starts_at_local.hour, stay_definition.starts_at_local.min ]
    assert_equal [ 12, 0 ], [ stay_definition.ends_at_local.hour, stay_definition.ends_at_local.min ]
    assert_empty @version.capacity_pool_definitions.where(service_occurrence: stay)
    assert_empty CapacityPool.where(service_occurrence: stay)

    [ november_4, november_5 ].each do |occurrence|
      inventory = definition_for(occurrence)
      assert_equal inventory.starts_on, inventory.ends_on
      assert_nil inventory.starts_at_local
      assert_nil inventory.ends_at_local
    end

    pairs = @version.capacity_pair_definitions.where(arrangement_item: item)
    assert_equal 6, pairs.count
    assert_equal 2, pairs.where(classification: "not_applicable", service_occurrence: stay).count
    assert_equal 4, pairs.where(classification: "pooled").count
    openings.each do |(occurrence, resource), quantity|
      pool_definition = @version.capacity_pool_definitions.find_by!(
        service_occurrence: occurrence, supplier_resource: resource
      )
      pool = pool_definition.capacity_pool
      assert_equal "block", pool.inventory_mode
      assert_equal "resource_units", pool.measurement_basis
      assert_predicate pool, :numeric_inventory?
      assert_equal quantity, pool_definition.proposed_opening_quantity
      assert_equal 1, @version.capacity_pool_definitions.where(capacity_pair_definition: pool_definition.capacity_pair_definition).count
    end

    guest = CreateSupplierCostParticipantCategory.new(
      agency: @agency, actor: @admin, arrangement_item: item,
      version_lock_version: lock_version, label: "Guest",
      idempotency_key: "hilton-guest"
    ).call.record
    rates = { standard => 17_300, deluxe => 22_300 }
    sources = openings.map do |(occurrence, resource), quantity|
      price_night!(item, occurrence, resource, guest, quantity, rates.fetch(resource))
    end

    assumptions = @version.supplier_cost_usage_assumptions.where(arrangement_item: item)
    assert_equal [ 1 ], assumptions.map(&:expected_billable_nights).uniq
    assert_equal 0, @version.supplier_cost_components.where(economic_role: "expected_commission").count
    assert_equal [ "noncommissionable" ], @version.supplier_cost_definitions.where(supplier_cost_source: sources).distinct.pluck(:commission_treatment)
    bases = @version.supplier_cost_components.where(quantity_basis: "resource_nights")
    increments = @version.supplier_cost_components.where(quantity_basis: "occupancy_position_nights")
    assert_equal [ 17_300, 17_300, 22_300, 22_300 ], bases.order(:amount_minor_units).pluck(:amount_minor_units)
    assert bases.all? { |component| component.occupancy_position_from.nil? && component.occupancy_position_to.nil? }
    assert_equal [ 2_000 ] * 8, increments.order(:amount_minor_units).pluck(:amount_minor_units)
    assert_equal [ 3, 3, 3, 3 ], increments.where(occupancy_position_from: 3, occupancy_position_to: 3).pluck(:occupancy_position_from)
    assert_equal [ 4, 4, 4, 4 ], increments.where(occupancy_position_from: 4, occupancy_position_to: 4).pluck(:occupancy_position_from)
    assert_empty @version.supplier_cost_components.where(amount_minor_units: [ 19_300, 21_300, 24_300, 26_300 ])

    standard_night = source_for(sources, november_4, standard)
    deluxe_night = source_for(sources, november_4, deluxe)
    assert_equal [ 17_300, 17_300, 19_300, 21_300 ], (1..4).map { |count| room_occupancy_total(standard_night, count) }
    assert_equal [ 22_300, 22_300, 24_300, 26_300 ], (1..4).map { |count| room_occupancy_total(deluxe_night, count) }

    forecast = evaluate
    assert_equal 415_600, forecast.totals.forecast_supplier_cost_minor_units
    assert_equal 0, forecast.totals.expected_commission_minor_units
    assert_equal 831_200, nights_total(sources, 2)
    assert_not_equal 831_200, forecast.totals.forecast_supplier_cost_minor_units

    create_deposits!
    deposits = @version.supplier_deposit_requirement_definitions.order(:position)
    record_hilton_terms!(item, november_4, november_5, standard, deluxe, deposits)
    assert_equal [ 41_560, 187_020, 187_020 ], deposits.map(&:fixed_amount_minor_units)
    assert_equal [ "2026-10-01", "2027-05-07", "2027-10-04" ], deposits.map { |row| row.rule_parameters["date"] }
    assert deposits.all? { |row| row.fixed_amount? && row.percentage.nil? && row.target_amount_minor_units.nil? }
    assert_equal 3, deposits.count
    assert deposits.none?(&:percentage_of_cost_sources?)

    create_cutoff!(item)
    deadline = @version.supplier_deadline_definitions.sole
    assert_equal "rooming_list_due", deadline.deadline_type
    assert_equal "actionable", deadline.kind
    assert_equal "fixed_local_datetime", deadline.rule_shape
    assert_equal "local_date_time", deadline.precision
    assert_equal "America/New_York", deadline.time_zone
    assert_equal "2027-10-03T17:00:00", deadline.rule_parameters["datetime"]
    assert_equal [ "datetime" ], deadline.rule_parameters.keys

    confirmation = confirm_supplier!(reference_note: "Hilton confirmed the room block.")
    assert_equal Date.new(2026, 9, 28), confirmation.evidence_on
    assert_equal "email", confirmation.channel
    assert_equal "No hotel number was issued.", confirmation.confirmed_without_identifier_reason
    assert_equal 0, SupplierArrangementCruiseAgreementConfirmation.where(supplier_arrangement_id: confirmation.supplier_arrangement_id).count
    assert_equal 0, SupplierArrangementCruiseAgreementConfirmation.where(supplier_arrangement: @arrangement).count
    assert_not_includes SupplierConfirmation.column_names, "contract_date"
    assert_not_includes SupplierConfirmation.column_names, "group_reference"

    openings_before = pool_openings(item)
    forecast_before = evaluate.totals.forecast_supplier_cost_minor_units
    deposit_ids = deposits.map(&:id)
    second_item = create_item("Second hotel")
    mark_managed!(second_item)
    second_resource = create_resource(second_item, "Second standard")
    second_occurrence = create_occurrence(
      second_item, "Second stay", starts_on: "2027-11-04", ends_on: "2027-11-04"
    )
    classify!(second_item, second_occurrence, second_resource, "not_applicable")

    assert_equal openings_before, pool_openings(item)
    assert_equal forecast_before, evaluate.totals.forecast_supplier_cost_minor_units
    assert_equal deposit_ids, @version.supplier_deposit_requirement_definitions.order(:position).map(&:id)
    assert_equal 6, @version.capacity_pair_definitions.where(arrangement_item: item).count
    assert_nil @version.supplier_deposit_bases.find_by(arrangement_item: second_item)
    assert_nil @version.hotel_attrition_policies.find_by(arrangement_item: second_item)
    assert_nil @version.supplier_deposit_refund_clarifications.find_by(arrangement_item: second_item)
    assert_equal 415_600, @version.supplier_deposit_bases.find_by!(arrangement_item: item).basis_amount_minor_units

    assert_typed_supplier_terms!(item, november_4, november_5, standard, deluxe, deposits, deadline, confirmation)
  end

  private

  def assert_typed_supplier_terms!(item, november_4, november_5, standard, deluxe, deposits, deadline, confirmation)
    net_source = contrast_cost(notes: "Net and noncommissionable. Commission will not be paid.")
    unset_source = contrast_cost(notes: nil)
    assert_equal "unspecified", net_source.supplier_cost_definitions.sole.commission_treatment
    assert_equal "unspecified", unset_source.supplier_cost_definitions.sole.commission_treatment
    assert_equal 0, net_source.supplier_cost_definitions.sole.supplier_cost_components.where(economic_role: "expected_commission").count
    assert_equal 0, unset_source.supplier_cost_definitions.sole.supplier_cost_components.where(economic_role: "expected_commission").count

    basis = @version.supplier_deposit_bases.find_by!(arrangement_item: item)
    assert_equal "original_contracted_room_revenue", basis.basis_kind
    assert_equal 415_600, basis.basis_amount_minor_units
    assert_equal "USD", basis.currency
    lines = basis.supplier_deposit_basis_entries
    assert_equal [ 44_600, 86_500, 111_500, 173_000 ], lines.map(&:extended_amount_minor_units).sort
    assert_equal(
      {
        [ november_4.id, standard.id ] => [ 5, 17_300, 86_500 ],
        [ november_4.id, deluxe.id ] => [ 2, 22_300, 44_600 ],
        [ november_5.id, standard.id ] => [ 10, 17_300, 173_000 ],
        [ november_5.id, deluxe.id ] => [ 5, 22_300, 111_500 ]
      },
      lines.to_h { |line|
        [ [ line.service_occurrence_id, line.supplier_resource_id ],
          [ line.agreed_quantity, line.agreed_unit_rate_minor_units, line.extended_amount_minor_units ] ]
      }
    )
    assert_equal [ 1_000, 4_500, 4_500 ], basis.supplier_deposit_basis_shares.order(:share_basis_points).map(&:share_basis_points)
    assert deposits.all? { |row| row.percentage.nil? && row.rule_parameters.keys == [ "date" ] }

    derived = contrast_deposit(description: derivation_prose)
    assert_equal({ "date" => "2027-05-07" }, derived.rule_parameters)
    probed_deadline = contrast_deadline
    assert_equal [ "datetime" ], probed_deadline.rule_parameters.keys
    assert_equal [ "datetime" ], deadline.rule_parameters.keys

    policy = @version.hotel_attrition_policies.find_by!(arrangement_item: item)
    assert_equal "lost_room_revenue", policy.consequence
    assert_equal 10_000, policy.consequence_basis_points
    assert_equal 1_650, policy.quoted_tax_rate_basis_points
    assert_equal(
      { november_4.id => 7, november_5.id => 15 },
      policy.hotel_attrition_nights.to_h { |night| [ night.service_occurrence_id, night.minimum_utilized_room_nights ] }
    )
    assert_equal(
      { standard.id => 17_300, deluxe.id => 22_300 },
      policy.hotel_attrition_zero_utilization_rates.to_h { |rate| [ rate.supplier_resource_id, rate.amount_minor_units ] }
    )

    clarification = @version.supplier_deposit_refund_clarifications.find_by!(arrangement_item: item)
    assert_equal "Deposits are non-refundable.", clarification.original_wording
    assert_equal(
      "The Hotel refunds the agency on or before November 20, 2027, the amount actually paid toward the deposits minus the attrition shortfall.",
      clarification.governing_wording
    )
    assert_equal "agency", clarification.payer
    assert_equal "agency", clarification.recipient
    assert_equal Date.new(2027, 11, 20), clarification.refund_due_on
    assert_not_equal clarification.class.name, confirmation.class.name
    %w[original_wording governing_wording payer recipient refund_due_on].each do |column|
      assert_not_includes SupplierConfirmation.column_names, column
    end
    noted = confirm_supplier!(reference_note: "Evidence note only.")
    assert_equal confirmation.evidence_on, noted.evidence_on
    assert_equal confirmation.channel, noted.channel
    assert_equal confirmation.confirmed_without_identifier_reason, noted.confirmed_without_identifier_reason
    assert_equal "Hilton confirmed the room block.", confirmation.reference_note
  end

  def record_hilton_terms!(item, november_4, november_5, standard, deluxe, deposits)
    CreateSupplierDepositBasis.new(
      agency: @agency, actor: @admin, arrangement_item: item, currency: "USD",
      basis_amount_minor_units: 415_600, idempotency_key: "hilton-basis",
      entries: [
        [ november_4, standard, 5, 17_300, 86_500 ],
        [ november_4, deluxe, 2, 22_300, 44_600 ],
        [ november_5, standard, 10, 17_300, 173_000 ],
        [ november_5, deluxe, 5, 22_300, 111_500 ]
      ].map { |occurrence, resource, quantity, rate, extended|
        {
          service_occurrence_id: occurrence.id, supplier_resource_id: resource.id,
          agreed_quantity: quantity, agreed_unit_rate_minor_units: rate,
          extended_amount_minor_units: extended
        }
      },
      shares: deposits.zip([ 1_000, 4_500, 4_500 ]).map { |requirement, points|
        { supplier_deposit_requirement_definition_id: requirement.id, share_basis_points: points }
      }
    ).call
    RecordHotelAttritionPolicy.new(
      agency: @agency, actor: @admin, arrangement_item: item,
      quoted_tax_rate_basis_points: 1_650, idempotency_key: "hilton-attrition",
      nights: [
        { service_occurrence_id: november_4.id, minimum_utilized_room_nights: 7 },
        { service_occurrence_id: november_5.id, minimum_utilized_room_nights: 15 }
      ],
      zero_utilization_rates: [
        { supplier_resource_id: standard.id, amount_minor_units: 17_300 },
        { supplier_resource_id: deluxe.id, amount_minor_units: 22_300 }
      ]
    ).call
    RecordSupplierDepositRefundClarification.new(
      agency: @agency, actor: @admin, arrangement_item: item, idempotency_key: "hilton-refund",
      original_wording: "Deposits are non-refundable.",
      governing_wording: "The Hotel refunds the agency on or before November 20, 2027, the amount actually paid toward the deposits minus the attrition shortfall.",
      refund_due_on: Date.new(2027, 11, 20)
    ).call
  end

  def derivation_prose
    "45% of $4,156 from nightly totals $1,311 and $2,845, in a 10/45/45 schedule."
  end

  def refund_sentence
    "Original wording: nonrefundable. Governing clarification: the Agency pays and the Agency receives any refund. Deadline November 20, 2027."
  end

  def attrition_prose
    "Nightly minimums 7 and 15, 100% shortfall, and zero-utilization fallback of $173, $223, and 16.5%."
  end

  def typed_cost_state(source)
    definition = source.supplier_cost_definitions.sole
    {
      notes_column_type: SupplierCostSource.columns_hash["notes"].type,
      roles: definition.supplier_cost_components.order(:position).pluck(:economic_role),
      commission_columns: (
        SupplierCostSource.column_names + SupplierCostDefinition.column_names
      ).grep(/commission|noncommission|net_term/i)
    }
  end

  def contrast_cost(notes:)
    arrangement = CreateSupplierArrangement.new(
      agency: @agency, actor: @admin, departure: @departure,
      idempotency_key: "contrast-cost-#{notes.to_s.hash}",
      attributes: {
        name: "Commission contrast #{notes.to_s.hash}",
        contracting_supplier_id: @contractor.id,
        supplier_contact_id: @contact.id
      }
    ).call.record
    version = arrangement.versions.sole
    item = CreateArrangementItem.new(
      agency: @agency, actor: @admin, arrangement: arrangement,
      version_lock_version: version.lock_version, idempotency_key: SecureRandom.uuid,
      attributes: { name: "Contrast item", category: "lodging" }
    ).call.record
    source = CreateSupplierCostSource.new(
      agency: @agency, actor: @admin, arrangement: arrangement,
      version_lock_version: version.reload.lock_version, idempotency_key: SecureRandom.uuid,
      attributes: {
        arrangement_item_id: item.id, charging_supplier_id: @contractor.id,
        label: "Room charge", notes: notes
      }
    ).call.record
    definition = CreateSupplierCostDefinition.new(
      agency: @agency, actor: @admin, source: source,
      source_lock_version: source.lock_version, idempotency_key: SecureRandom.uuid,
      attributes: { stage: "contracted", mode: "calculated", currency: "USD", rounding_mode: "half_up" }
    ).call.record
    CreateSupplierCostComponent.new(
      agency: @agency, actor: @admin, definition: definition,
      definition_lock_version: definition.lock_version, idempotency_key: SecureRandom.uuid,
      attributes: {
        label: "Room", economic_role: "supplier_charge", calculation_kind: "fixed",
        amount_minor_units: 187_020, pass_through: false
      }
    ).call
    source
  end

  def contrast_deposit(description:)
    arrangement = CreateSupplierArrangement.new(
      agency: @agency, actor: @admin, departure: @departure,
      idempotency_key: "contrast-deposit-#{description.to_s.hash}",
      attributes: {
        name: "Deposit contrast #{description.to_s.hash}",
        contracting_supplier_id: @contractor.id,
        supplier_contact_id: @contact.id
      }
    ).call.record
    version = arrangement.versions.sole
    CreateSupplierDepositRequirementDefinition.new(
      agency: @agency, actor: @admin, version: version,
      version_lock_version: version.lock_version, idempotency_key: SecureRandom.uuid,
      attributes: {
        amount_shape: "fixed_amount",
        fixed_amount_minor_units: 187_020,
        currency: "USD",
        rule_shape: "fixed_date",
        rule_parameters: {
          "date" => "2027-05-07",
          "nightly_totals_minor_units" => [ 131_100, 284_500 ],
          "shares" => [ 10, 45, 45 ],
          "basis_minor_units" => 415_600
        },
        precision: "date_only",
        time_zone: "America/New_York",
        description: description,
        coverage_links: [],
        cost_links: [],
        contributor_definition_ids: []
      }
    ).call.record
  end

  def price_night!(item, occurrence, resource, guest, quantity, base_minor_units)
    assumption = CreateSupplierCostUsageAssumption.new(
      agency: @agency, actor: @admin, arrangement_item: item,
      idempotency_key: SecureRandom.uuid,
      attributes: {
        service_occurrence_id: occurrence.id,
        supplier_resource_id: resource.id,
        expected_billable_nights: 1
      }
    ).call.record
    CreateSupplierCostOccupancyProfile.new(
      agency: @agency, actor: @admin, assumption: assumption,
      assumption_lock_version: assumption.lock_version, idempotency_key: SecureRandom.uuid,
      attributes: { label: "Contracted rooms", resource_unit_count: quantity },
      positions: [ { participant_category_id: guest.id } ]
    ).call
    source = CreateSupplierCostSource.new(
      agency: @agency, actor: @admin, arrangement: @arrangement,
      version_lock_version: lock_version, idempotency_key: SecureRandom.uuid,
      attributes: {
        arrangement_item_id: item.id,
        service_occurrence_id: occurrence.id,
        supplier_resource_id: resource.id,
        charging_supplier_id: @contractor.id,
        label: "#{definition_for(occurrence).name} #{resource_name(resource)}"
      }
    ).call.record
    definition = CreateSupplierCostDefinition.new(
      agency: @agency, actor: @admin, source: source,
      source_lock_version: source.lock_version, idempotency_key: SecureRandom.uuid,
      attributes: { stage: "contracted", mode: "calculated", currency: "USD", rounding_mode: "half_up" }
    ).call.record
    [
      [ "Room night base", base_minor_units, "resource_nights", nil, nil ],
      [ "Third occupant", 2_000, "occupancy_position_nights", 3, 3 ],
      [ "Fourth occupant", 2_000, "occupancy_position_nights", 4, 4 ]
    ].each do |label, amount, basis, from, to|
      attributes = {
        label: label, economic_role: "supplier_charge", calculation_kind: "unit_rate",
        amount_minor_units: amount, quantity_basis: basis, pass_through: false
      }
      attributes[:occupancy_position_from] = from if from
      attributes[:occupancy_position_to] = to if to
      CreateSupplierCostComponent.new(
        agency: @agency, actor: @admin, definition: definition.reload,
        definition_lock_version: definition.lock_version, idempotency_key: SecureRandom.uuid,
        attributes: attributes
      ).call
    end
    SetSupplierCostCommissionTreatment.new(
      agency: @agency, actor: @admin, definition: definition.reload,
      commission_treatment: "noncommissionable", lock_version: definition.lock_version
    ).call
    MarkCostDefinitionForecastReady.new(
      agency: @agency, actor: @admin, definition: definition.reload,
      lock_version: definition.lock_version,
      readiness_provenance: "Hilton one-night room rate"
    ).call
    source
  end

  def nights_total(sources, nights)
    sources.sum do |source|
      assumption = @version.supplier_cost_usage_assumptions.find_by!(
        service_occurrence_id: source.service_occurrence_id,
        supplier_resource_id: source.supplier_resource_id
      )
      profile = assumption.supplier_cost_occupancy_profiles.sole
      usage = EvaluateSupplierCostForecast::EphemeralUsage.new(
        id: "nights-#{nights}-#{source.id}",
        expected_persons: nil,
        expected_resource_units: nil,
        expected_billable_nights: nights
      )
      rows = EvaluateSupplierCostForecast.new(
        agency: @agency, departure: @departure, arrangement: @arrangement
      ).call_attributed_sources(
        sources: [ source ],
        usage: usage,
        profiles: [ profile ],
        positions_by_profile: {
          profile.id => profile.supplier_cost_occupancy_profile_positions.order(:occupancy_position).to_a
        }
      )
      rows.sole.totals.forecast_supplier_cost_minor_units
    end
  end

  def source_for(sources, occurrence, resource)
    sources.find do |source|
      source.service_occurrence_id == occurrence.id && source.supplier_resource_id == resource.id
    end
  end

  def room_occupancy_total(source, position_count)
    profile = Struct.new(:id, :resource_unit_count).new("one-room-#{position_count}-#{source.id}", 1)
    positions = Array.new(position_count) do |index|
      EvaluateSupplierCostForecast::EphemeralPosition.new(
        id: index + 1, occupancy_position: index + 1, participant_category_id: nil
      )
    end
    usage = EvaluateSupplierCostForecast::EphemeralUsage.new(
      id: "occupancy-#{position_count}-#{source.id}",
      expected_persons: nil,
      expected_resource_units: nil,
      expected_billable_nights: 1
    )
    rows = EvaluateSupplierCostForecast.new(
      agency: @agency, departure: @departure, arrangement: @arrangement
    ).call_attributed_sources(
      sources: [ source ],
      usage: usage,
      profiles: [ profile ],
      positions_by_profile: { profile.id => positions }
    )
    rows.sole.totals.forecast_supplier_cost_minor_units
  end

  def confirm_supplier!(reference_note:)
    departure = CreateDeparture.new(
      agency: @agency, actor: @admin,
      attributes: {
        name: "Confirmation #{SecureRandom.hex(4)}",
        starts_on: Date.new(2027, 11, 4),
        ends_on: Date.new(2027, 11, 6),
        time_zone: "America/New_York",
        operating_currency: "USD",
        responsible_office_id: @office.id,
        responsible_agency_user_id: @admin.id
      },
      current_office: @office
    ).call.record
    ActivateDeparture.new(
      agency: @agency, actor: @admin, departure: departure, lock_version: departure.lock_version
    ).call
    arrangement = CreateSupplierArrangement.new(
      agency: @agency, actor: @admin, departure: departure,
      idempotency_key: SecureRandom.uuid,
      attributes: {
        name: "Confirmation stay",
        contracting_supplier_id: @contractor.id,
        supplier_contact_id: @contact.id
      }
    ).call.record
    version = arrangement.versions.sole
    item = CreateArrangementItem.new(
      agency: @agency, actor: @admin, arrangement: arrangement,
      version_lock_version: version.lock_version, idempotency_key: SecureRandom.uuid,
      attributes: { name: "Stay", category: "lodging", default_service_provider_id: @contractor.id }
    ).call.record
    item_definition = version.arrangement_item_definitions.find_by!(arrangement_item: item)
    SetItemCapacityManagement.new(
      agency: @agency, actor: @admin, definition: item_definition,
      capacity_management: "unmanaged", lock_version: item_definition.lock_version
    ).call
    CreateServiceOccurrence.new(
      agency: @agency, actor: @admin, item: item,
      version_lock_version: version.reload.lock_version, idempotency_key: SecureRandom.uuid,
      attributes: { name: "Stay", starts_on: "2027-11-04", ends_on: "2027-11-06" }
    ).call
    CreateSupplierResource.new(
      agency: @agency, actor: @admin, item: item,
      version_lock_version: version.reload.lock_version, idempotency_key: SecureRandom.uuid,
      attributes: { name: "Room" }
    ).call
    source = CreateSupplierCostSource.new(
      agency: @agency, actor: @admin, arrangement: arrangement,
      version_lock_version: version.reload.lock_version, idempotency_key: SecureRandom.uuid,
      attributes: {
        arrangement_item_id: item.id, charging_supplier_id: @contractor.id, label: "Included stay"
      }
    ).call.record
    definition = CreateSupplierCostDefinition.new(
      agency: @agency, actor: @admin, source: source,
      source_lock_version: source.lock_version, idempotency_key: SecureRandom.uuid,
      attributes: {
        stage: "contracted", mode: "zero_cost", currency: "USD", rounding_mode: "half_up",
        zero_cost_reason: "Included in the hotel stay"
      }
    ).call.record
    MarkCostDefinitionForecastReady.new(
      agency: @agency, actor: @admin, definition: definition.reload,
      lock_version: definition.lock_version, readiness_provenance: "Confirmation proof"
    ).call
    ActivateSupplierArrangementVersion.new(
      agency: @agency, actor: @admin, arrangement: arrangement.reload, version: version.reload,
      arrangement_lock_version: arrangement.lock_version,
      version_lock_version: version.lock_version,
      cost_source_coverage_acknowledged: true,
      commitment_trigger_coverage_acknowledged: true,
      evidence_attributes: {
        evidence_kind: "supplier_confirmation",
        evidence_on: Date.new(2026, 9, 28),
        channel: "email",
        reference_note: reference_note,
        confirmed_without_identifier_reason: "No hotel number was issued."
      },
      idempotency_key: SecureRandom.uuid
    ).call
    SupplierConfirmation.find_by!(supplier_arrangement: arrangement)
  end

  def contrast_deadline
    arrangement = CreateSupplierArrangement.new(
      agency: @agency, actor: @admin, departure: @departure,
      idempotency_key: SecureRandom.uuid,
      attributes: {
        name: "Attrition contrast",
        contracting_supplier_id: @contractor.id,
        supplier_contact_id: @contact.id
      }
    ).call.record
    version = arrangement.versions.sole
    CreateSupplierDeadlineDefinition.new(
      agency: @agency, actor: @admin, version: version,
      version_lock_version: version.lock_version, idempotency_key: SecureRandom.uuid,
      attributes: {
        deadline_type: "rooming_list_due",
        kind: "actionable",
        rule_shape: "fixed_local_datetime",
        rule_parameters: {
          "datetime" => "2027-10-03T17:00:00",
          "nightly_minimums" => [ 7, 15 ],
          "shortfall_consequence" => "100%",
          "zero_utilization" => { "standard" => 17_300, "deluxe" => 22_300, "tax_rate" => "16.5%" }
        },
        precision: "local_date_time",
        time_zone: "America/New_York",
        cardinality: "one_shared",
        description: attrition_prose,
        coverage_links: [],
        commitment_lines: []
      }
    ).call.record
  end

  def create_deposits!
    [
      [ 41_560, "2026-10-01" ],
      [ 187_020, "2027-05-07" ],
      [ 187_020, "2027-10-04" ]
    ].each do |amount, date|
      CreateSupplierDepositRequirementDefinition.new(
        agency: @agency, actor: @admin, version: @version.reload,
        version_lock_version: lock_version, idempotency_key: SecureRandom.uuid,
        attributes: {
          amount_shape: "fixed_amount",
          fixed_amount_minor_units: amount,
          currency: "USD",
          rule_shape: "fixed_date",
          rule_parameters: { "date" => date },
          precision: "date_only",
          time_zone: "America/New_York",
          coverage_links: [],
          cost_links: [],
          contributor_definition_ids: []
        }
      ).call
    end
  end

  def create_cutoff!(item)
    CreateSupplierDeadlineDefinition.new(
      agency: @agency, actor: @admin, version: @version.reload,
      version_lock_version: lock_version, idempotency_key: "hilton-cutoff",
      attributes: {
        deadline_type: "rooming_list_due",
        kind: "actionable",
        rule_shape: "fixed_local_datetime",
        rule_parameters: { "datetime" => "2027-10-03T17:00:00" },
        precision: "local_date_time",
        time_zone: "America/New_York",
        cardinality: "one_shared",
        coverage_links: [ { arrangement_item_id: item.id } ],
        commitment_lines: []
      }
    ).call
  end

  def evaluate
    EvaluateSupplierCostForecast.new(
      agency: @agency, departure: @departure, arrangement: @arrangement
    ).call
  end

  def pool_openings(item)
    @version.capacity_pool_definitions.where(arrangement_item: item).order(:created_at, :id).map(&:proposed_opening_quantity)
  end

  def create_item(name)
    CreateArrangementItem.new(
      agency: @agency, actor: @admin, arrangement: @arrangement,
      version_lock_version: lock_version, idempotency_key: SecureRandom.uuid,
      attributes: { name: name, category: "lodging", default_service_provider_id: @contractor.id }
    ).call.record
  end

  def mark_managed!(item)
    definition = @version.arrangement_item_definitions.find_by!(arrangement_item: item)
    SetItemCapacityManagement.new(
      agency: @agency, actor: @admin, definition: definition,
      capacity_management: "managed", lock_version: definition.lock_version
    ).call
  end

  def create_resource(item, name)
    CreateSupplierResource.new(
      agency: @agency, actor: @admin, item: item,
      version_lock_version: lock_version, idempotency_key: SecureRandom.uuid,
      attributes: { name: name, maximum_occupancy: 4 }
    ).call.record
  end

  def create_occurrence(item, name, attributes)
    CreateServiceOccurrence.new(
      agency: @agency, actor: @admin, item: item,
      version_lock_version: lock_version, idempotency_key: SecureRandom.uuid,
      attributes: { name: name }.merge(attributes)
    ).call.record
  end

  def classify!(item, occurrence, resource, classification)
    ClassifyCapacityPair.new(
      agency: @agency, actor: @admin, item: item,
      service_occurrence: occurrence, supplier_resource: resource,
      classification: classification, version_lock_version: lock_version
    ).call
  end

  def configure_pool!(item, occurrence, resource, quantity)
    ConfigureCapacityPairWithPool.new(
      agency: @agency, actor: @admin, item: item,
      service_occurrence: occurrence, supplier_resource: resource,
      version_lock_version: lock_version, idempotency_key: SecureRandom.uuid,
      pool_attributes: {
        inventory_mode: "block",
        measurement_basis: "resource_units",
        unit_label: "rooms",
        proposed_opening_quantity: quantity,
        label: "#{definition_for(occurrence).name} #{resource_name(resource)}",
        evidence_kind: "contract",
        evidence_on: "2026-09-30",
        evidence_reference_note: "Hilton room block"
      }
    ).call
  end

  def definition_for(occurrence)
    @version.service_occurrence_definitions.find_by!(service_occurrence: occurrence)
  end

  def resource_name(resource)
    @version.supplier_resource_definitions.find_by!(supplier_resource: resource).name
  end

  def lock_version
    @version.reload.lock_version
  end

  def ensure_supplier_sequence!(agency)
    agency.reference_sequences.find_or_create_by!(namespace: ReferenceSequence::SUPPLIER_NAMESPACE) do |sequence|
      sequence.next_value = 1
    end
  end
end
