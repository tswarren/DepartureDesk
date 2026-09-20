# frozen_string_literal: true

require "test_helper"

# M3F.2 integrated Celebrity Beyond and Vineyard Tour Supplier-side journeys.
# Ledger labels follow docs/planning/m3f-acceptance-and-hardening.md.
# M3E.7b remains slice baseline; this file owns the parent integrated composition.
class M3f2IntegratedScenarioJourneysTest < ActiveSupport::TestCase
  include M3fScenarioHelper

  setup do
    @agency = agencies(:harbor)
    @actor = agency_users(:harbor_staff)
    @other_agency = agencies(:cove)
  end

  test "Celebrity Beyond full Supplier journey with ledger-labeled facts" do
    # Confirmed sailing dates from celebrity-beyond-2027.md
    graph = m3f_activated_graph!(
      "M3F2 Celebrity",
      "Celebrity Beyond",
      starts_on: Date.new(2027, 11, 6),
      ends_on: Date.new(2027, 11, 13)
    )

    prestay = m3f_add_prestay_occurrence!(
      graph,
      starts_on: Date.new(2027, 11, 4),
      ends_on: Date.new(2027, 11, 5)
    )
    prestay_definition = graph[:version].service_occurrence_definitions
      .find_by!(service_occurrence_id: prestay.id)
    assert_operator prestay_definition.starts_on, :<, graph[:departure].starts_on,
      "Pre-stay precedes sailing (confirmed shape); Occurrence stays planned, not completed"
    assert_equal "planned", prestay.status

    o1_source = m3f_create_celebrity_o1_cost!(graph)
    o1_components = o1_source.supplier_cost_definitions.sole.supplier_cost_components.index_by(&:label)
    assert_equal CELEBRITY_O1_AMOUNTS.fetch(:first_second_fare),
      o1_components.fetch("First/second-position cruise fare").amount_minor_units,
      "ledger=#{LEDGER_CONFIRMED} M3C O1 first/second fare"
    assert_equal CELEBRITY_O1_AMOUNTS.fetch(:additional_fare),
      o1_components.fetch("Additional-position fare").amount_minor_units,
      "ledger=#{LEDGER_CONFIRMED}"
    assert_equal CELEBRITY_O1_AMOUNTS.fetch(:nccf),
      o1_components.fetch("NCCF").amount_minor_units,
      "ledger=#{LEDGER_CONFIRMED}"

    excursion = m3f_create_excursion_cost!(graph)
    rate = excursion.supplier_cost_definitions.sole.supplier_cost_components
      .find_by!(calculation_kind: "unit_rate")
    shortfall = excursion.supplier_cost_definitions.sole.supplier_cost_components
      .find_by!(calculation_kind: "minimum_quantity_shortfall")
    assert_equal 5_000, rate.amount_minor_units, "ledger=#{LEDGER_CONFIRMED} excursion $50"
    assert_equal 5, shortfall.minimum_quantity, "ledger=#{LEDGER_CONFIRMED} minimum five"

    forecast = EvaluateSupplierCostForecast.new(
      agency: @agency, departure: graph[:departure], arrangement: graph[:arrangement]
    ).call
    excursion_result = forecast.arrangements.first.sources.find { |row| row.source_id == excursion.id }
    assert excursion_result.complete, excursion_result.warnings.inspect
    shortfall_component = excursion_result.components.find { |row| row.label == "Minimum five" }
    assert_equal 10_000, shortfall_component.rounded_minor_units,
      "ledger=#{LEDGER_CONFIRMED} 2 missing × $50 = $100 shortfall"

    # Confirmed Arrangement-wide Celebrity deposits
    m3f_create_deposit!(
      graph,
      amount_shape: "quantity_times_rate",
      rate_minor_units: 5_000,
      quantity_basis: "resource_units",
      description: "Initial $50 per-cabin deposit (Arrangement-wide)",
      rule_shape: "fixed_date",
      rule_parameters: { "date" => "2027-01-15" },
      coverage_links: [ {
        arrangement_item_id: graph[:item].id,
        supplier_resource_id: graph[:resource].id
      } ]
    )
    m3f_create_deposit!(
      graph,
      amount_shape: "cumulative_target",
      target_amount_minor_units: 50_000,
      description: "Final cumulative $500 target",
      rule_shape: "earlier_of",
      rule_parameters: {
        "arms" => [
          { "rule_shape" => "fixed_date", "rule_parameters" => { "date" => "2027-03-11" } },
          {
            "rule_shape" => "planning_milestone",
            "rule_parameters" => { "kind" => "names_assigned_to_supplier" }
          }
        ]
      }
    )
    m3f_create_deadline!(
      graph,
      kind: "informational",
      deadline_type: "rooming_list_due",
      rule_shape: "days_before_departure",
      rule_parameters: { "days" => 60 }
    )

    assert_nil graph[:arrangement].try(:arrangement_reference)
    assert_nil graph[:arrangement].try(:reference)
    m3f_activate!(graph)
    graph[:arrangement].reload
    graph[:version].reload

    assert_equal "activated", graph[:version].status
    assert_equal "active", graph[:arrangement].status
    assert_raises(AgencyCommand::Error) do
      ReturnDepartureToDraft.new(
        agency: @agency, actor: @actor, departure: graph[:departure],
        reason: "Attempt return after Arrangement activation",
        lock_version: graph[:departure].reload.lock_version
      ).call
    end

    tranches = SupplierDepositRequirementTranche
      .where(supplier_arrangement_version: graph[:version])
      .order(:materialized_at, :id)
    assert_equal 2, tranches.count, "ledger=#{LEDGER_CONFIRMED} Arrangement-wide deposit pair"
    initial = tranches.find { |row| row.amount_shape == "quantity_times_rate" }
    final = tranches.find { |row| row.amount_shape == "cumulative_target" }
    assert_equal 5_000, initial.current_amount_minor_units
    assert_equal 45_000, final.current_amount_minor_units

    milestone_columns = SupplierPlanningMilestoneOccurrence.column_names
    assert_not_includes milestone_columns, "cabin_id",
      "names_assigned_to_supplier remains Arrangement-wide (confirmed)"

    reservation = CreateSupplierReservation.new(
      agency: @agency, actor: @actor, arrangement: graph[:arrangement],
      attributes: {
        booking_supplier_id: graph[:supplier].id,
        supplier_arrangement_version_id: graph[:version].id,
        scopes: [ { target_kind: "arrangement", label: "Group block" } ]
      },
      idempotency_key: SecureRandom.uuid
    ).call.record
    RecordSupplierReservationRequest.new(
      agency: @agency, actor: @actor, reservation:,
      attributes: { channel: "email", reference_note: "Block request" },
      idempotency_key: SecureRandom.uuid
    ).call
    scope = reservation.revisions.where(status: "requested").sole.scopes.sole
    RecordSupplierReservationResponse.new(
      agency: @agency, actor: @actor, reservation: reservation.reload,
      attributes: {
        channel: "portal",
        reference_note: "Confirmed",
        outcomes: {
          scope.id => { outcome_kind: "confirmed" }
        },
        evidence: {
          evidence_kind: "supplier_confirmation",
          evidence_on: Date.current,
          channel: "portal",
          reference_note: "Confirmed",
          confirmed_without_identifier_reason: "Portal"
        }
      },
      idempotency_key: SecureRandom.uuid
    ).call

    assert SupplierCommitment.where(
      supplier_arrangement: graph[:arrangement], opening_kind: "deposit_requirement"
    ).exists?
    assert SupplierCommitment.where(
      supplier_arrangement: graph[:arrangement], opening_kind: "confirmation_trigger"
    ).exists?
    exposure = SupplierExposureSummary.find_by(
      supplier_arrangement: graph[:arrangement], qualification_band: "forecast"
    )
    assert_not_nil exposure
    assert_operator exposure.gross_minor_units, :>, 0

    m3f_assert_no_client_commercial_tables!
    assert_equal 0,
      SupplierArrangement.where(agency_id: @other_agency.id, id: graph[:arrangement].id).count
  end

  test "Vineyard Tour Supplier journey uses illustrative costs and shape-only unresolved facts" do
    # Confirmed operating dates and 30-seat coach capacity shape from vineyard-tour-2027.md
    graph = m3f_activated_graph!(
      "M3F2 Vineyard",
      "Vineyard Tour",
      starts_on: Date.new(2027, 6, 5),
      ends_on: Date.new(2027, 6, 7),
      capacity_management: "managed"
    )
    graph[:item_definition].update!(capacity_management: "managed")
    pair = classify_capacity_graph_pair(graph)
    pool = CapacityPool.create!(
      agency: @agency, departure: graph[:departure],
      supplier_arrangement: graph[:arrangement],
      arrangement_item: graph[:item],
      service_occurrence: graph[:occurrence],
      supplier_resource: graph[:resource],
      supplying_supplier: graph[:supplier],
      inventory_mode: "block", measurement_basis: "traveler_positions",
      effective_time_zone: "America/New_York"
    )
    pool_definition = CapacityPoolDefinition.create!(
      agency: @agency, departure: graph[:departure],
      supplier_arrangement: graph[:arrangement],
      supplier_arrangement_version: graph[:version],
      arrangement_item: graph[:item],
      service_occurrence: graph[:occurrence],
      supplier_resource: graph[:resource],
      capacity_pair_definition: pair, capacity_pool: pool,
      label: "30-seat coach", normalized_label: "30-seat coach",
      unit_label: "seats", proposed_opening_quantity: 30,
      evidence_kind: "contract", evidence_on: Date.current,
      evidence_reference_note: "Coach block", override: false, position: 1
    )
    assert_equal 30, pool_definition.proposed_opening_quantity,
      "ledger=#{LEDGER_CONFIRMED} 30-seat coach"

    coach, tasting = m3f_create_vineyard_costs!(graph)
    assert_equal 120_000,
      coach.supplier_cost_definitions.sole.supplier_cost_components.sole.amount_minor_units,
      "ledger=#{LEDGER_ILLUSTRATIVE} fixed coach — not confirmed worksheet amount"
    assert_equal 5_000,
      tasting.supplier_cost_definitions.sole.supplier_cost_components.sole.amount_minor_units,
      "ledger=#{LEDGER_ILLUSTRATIVE} per-person tasting"

    m3f_add_dinner_items!(graph)
    dinner_names = graph[:version].arrangement_item_definitions
      .where("name LIKE ?", "%Dinner%").order(:position).pluck(:name)
    assert_equal [ "Standard Dinner", "Deluxe Dinner" ], dinner_names,
      "ledger=#{LEDGER_CONFIRMED} separate Supplier Items; Client choice deferred to M4"

    # Shape-only: unresolved hotel sequence / package price / min enrollment must not appear
    # as invented acceptance amounts on this Arrangement.
    unresolved_labels = graph[:arrangement].supplier_cost_sources.pluck(:label)
    assert_not unresolved_labels.any? { |label| label.match?(/Hotel A|package price|min enrollment/i) },
      "ledger=#{LEDGER_SHAPE_ONLY} do not invent Vineyard worksheet gaps"

    m3f_create_deadline!(
      graph,
      kind: "informational",
      deadline_type: "final_count_due",
      rule_shape: "days_before_departure",
      rule_parameters: { "days" => 14 }
    )
    m3f_activate!(graph)

    assert_equal "activated", graph[:version].reload.status
    forecast_band = SupplierExposureSummary.find_by(
      supplier_arrangement: graph[:arrangement], qualification_band: "forecast"
    )
    assert_not_nil forecast_band
    # Fixed coach + 12 × tasting illustrative totals
    assert_equal 180_000, forecast_band.gross_minor_units,
      "ledger=#{LEDGER_ILLUSTRATIVE} 120000 + 12*5000"

    m3f_assert_no_client_commercial_tables!
  end

  test "draft Departure keeps planning tentative and blocks activation" do
    supplier = create_capacity_supplier(@agency, "M3F2 Draft Supplier")
    departure = create_capacity_departure(@agency, name: "M3F2 Draft Departure", status: "draft")
    graph = create_capacity_graph(
      agency: @agency, departure:, contractor: supplier, provider: supplier,
      prefix: "M3F2 Draft", capacity_management: "unmanaged"
    ).merge(supplier:, departure:, actor: @actor)
    m3f_create_ready_cost!(graph)
    m3f_create_confirmation_trigger!(graph)

    error = assert_raises(AgencyCommand::Error) { m3f_activate!(graph) }
    assert_match(/active|draft|invalid/i, error.message)
    assert_equal "draft", graph[:version].reload.status
  end
end
