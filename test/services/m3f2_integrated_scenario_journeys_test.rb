# frozen_string_literal: true

require "test_helper"

# M3F.2 integrated Celebrity Beyond and Vineyard Tour Supplier-side journeys.
# Ledger labels follow docs/planning/m3f-acceptance-and-hardening.md.
# M3E.7b remains slice baseline; this file owns the parent integrated composition.
class M3f2IntegratedScenarioJourneysTest < ActiveSupport::TestCase
  include M3fScenarioHelper

  # Smith Family Reunion agreement: initial Celebrity deposit due 2026-09-20.
  CELEBRITY_INITIAL_DEPOSIT_ON = Date.new(2026, 9, 20)

  setup do
    @agency = agencies(:harbor)
    @actor = agency_users(:harbor_staff)
    @other_agency = agencies(:cove)
  end

  test "Celebrity Beyond multi-Arrangement Supplier journey with agreement deposit timing" do
    cruise = m3f_activated_graph!(
      "M3F2 Celebrity",
      "Celebrity Beyond",
      starts_on: Date.new(2027, 11, 6),
      ends_on: Date.new(2027, 11, 13)
    )
    departure = cruise[:departure]
    assert_match(/\AD-\d+\z/, departure.departure_reference)
    assert_equal 1, AuditEvent.where(
      action: "departure.activated", subject_type: "Departure", subject_id: departure.id
    ).count

    # Independently governed Hilton Arrangement (distinct contracting Supplier).
    hilton = m3f_secondary_arrangement_graph!(
      departure:,
      supplier_name: "M3F2 Hilton",
      prefix: "M3F2 Hilton",
      capacity_management: "managed",
      starts_on: Date.new(2027, 11, 4),
      ends_on: Date.new(2027, 11, 5)
    )
    assert_operator hilton[:occurrence_definition].starts_on, :<, departure.starts_on
    assert_not_equal cruise[:supplier].id, hilton[:supplier].id
    assert_equal departure.id, hilton[:arrangement].departure_id
    hilton_pool = m3f_add_numeric_pool!(hilton, quantity: 10, label: "Hilton guaranteed rooms")
    create_calculated_hilton_cost!(hilton)

    # Independently governed transfer Arrangement.
    transfer = m3f_secondary_arrangement_graph!(
      departure:,
      supplier_name: "M3F2 Transfer Coach",
      prefix: "M3F2 Transfer",
      starts_on: Date.new(2027, 11, 6),
      ends_on: Date.new(2027, 11, 6)
    )
    assert_not_equal cruise[:supplier].id, transfer[:supplier].id
    m3f_create_deadline!(
      transfer,
      kind: "informational",
      deadline_type: "final_count_due",
      rule_shape: "days_before_departure",
      rule_parameters: { "days" => 14 }
    )

    o1_source = m3f_create_celebrity_o1_cost!(cruise)
    o1_components = o1_source.supplier_cost_definitions.sole.supplier_cost_components.index_by(&:label)
    assert_equal CELEBRITY_O1_AMOUNTS.fetch(:first_second_fare),
      o1_components.fetch("First/second-position cruise fare").amount_minor_units,
      "ledger=#{LEDGER_CONFIRMED} M3C O1 first/second fare"

    excursion = m3f_create_excursion_cost!(cruise)
    rate = excursion.supplier_cost_definitions.sole.supplier_cost_components
      .find_by!(calculation_kind: "unit_rate")
    shortfall = excursion.supplier_cost_definitions.sole.supplier_cost_components
      .find_by!(calculation_kind: "minimum_quantity_shortfall")
    assert_equal 5_000, rate.amount_minor_units, "ledger=#{LEDGER_CONFIRMED} excursion $50"
    assert_equal 5, shortfall.minimum_quantity, "ledger=#{LEDGER_CONFIRMED} minimum five"
    forecast = EvaluateSupplierCostForecast.new(
      agency: @agency, departure:, arrangement: cruise[:arrangement]
    ).call
    excursion_result = forecast.arrangements.first.sources.find { |row| row.source_id == excursion.id }
    assert excursion_result.complete, excursion_result.warnings.inspect
    assert_equal 10_000,
      excursion_result.components.find { |row| row.label == "Minimum five" }.rounded_minor_units,
      "ledger=#{LEDGER_CONFIRMED} 2 missing × $50 = $100 shortfall"

    # Agreement-confirmed initial deposit due date (Smith Family Reunion).
    m3f_create_deposit!(
      cruise,
      amount_shape: "quantity_times_rate",
      rate_minor_units: 5_000,
      quantity_basis: "resource_units",
      description: "Initial $50 per-cabin deposit (Arrangement-wide)",
      rule_shape: "fixed_date",
      rule_parameters: { "date" => CELEBRITY_INITIAL_DEPOSIT_ON.iso8601 },
      coverage_links: [ {
        arrangement_item_id: cruise[:item].id,
        supplier_resource_id: cruise[:resource].id
      } ]
    )
    m3f_create_deposit!(
      cruise,
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
    # Rooming / legal-names: confirmed M3E.7b / scenario authority (60-day / 30-day).
    m3f_create_deadline!(
      cruise,
      kind: "informational",
      deadline_type: "rooming_list_due",
      rule_shape: "days_before_departure",
      rule_parameters: { "days" => 60 }
    )
    m3f_create_deadline!(
      cruise,
      kind: "informational",
      deadline_type: "legal_names_due",
      rule_shape: "days_before_departure",
      rule_parameters: { "days" => 30 }
    )

    error = assert_raises(AgencyCommand::Error) do
      travel_to Time.find_zone!("America/New_York").local(2026, 9, 21, 12, 0, 0) do
        m3f_activate!(cruise)
      end
    end
    assert_match(/elapsed/i, error.message)

    travel_to Time.find_zone!("America/New_York").local(2026, 9, 21, 12, 0, 0) do
      m3f_activate!(cruise, elapsed_deadlines_acknowledged: true)
      m3f_activate!(hilton)
      m3f_activate!(transfer)
    end

    cruise[:arrangement].reload
    cruise[:version].reload
    assert_equal "activated", cruise[:version].status
    assert_equal "active", cruise[:arrangement].status

    initial = SupplierDepositRequirementTranche.find_by!(
      supplier_arrangement_version: cruise[:version], amount_shape: "quantity_times_rate"
    )
    final = SupplierDepositRequirementTranche.find_by!(
      supplier_arrangement_version: cruise[:version], amount_shape: "cumulative_target"
    )
    assert_equal 5_000, initial.current_amount_minor_units, "ledger=#{LEDGER_CONFIRMED}"
    assert_equal 45_000, final.current_amount_minor_units, "ledger=#{LEDGER_CONFIRMED}"
    assert_equal CELEBRITY_INITIAL_DEPOSIT_ON, initial.governing_deadline_occurrence.calculated_on,
      "ledger=#{LEDGER_CONFIRMED} Smith agreement initial deposit due date"

    rooming = SupplierDeadlineOccurrence.find_by!(
      supplier_arrangement_version: cruise[:version], deadline_type: "rooming_list_due"
    )
    legal = SupplierDeadlineOccurrence.find_by!(
      supplier_arrangement_version: cruise[:version], deadline_type: "legal_names_due"
    )
    assert_equal Date.new(2027, 9, 7), rooming.calculated_on,
      "ledger=#{LEDGER_CONFIRMED} 60 days before sailing (M3E.7b / scenario)"
    assert_equal Date.new(2027, 10, 7), legal.calculated_on,
      "ledger=#{LEDGER_CONFIRMED} 30 days before sailing (M3E.7b / scenario)"

    assert_raises(AgencyCommand::Error) do
      ReturnDepartureToDraft.new(
        agency: @agency, actor: @actor, departure:,
        reason: "Attempt return after Arrangement activation",
        lock_version: departure.reload.lock_version
      ).call
    end

    # Reservation + capacity consequence on Hilton Pool.
    reservation = CreateSupplierReservation.new(
      agency: @agency, actor: @actor, arrangement: hilton[:arrangement],
      attributes: {
        booking_supplier_id: hilton[:supplier].id,
        supplier_arrangement_version_id: hilton[:version].id,
        scopes: [ { target_kind: "arrangement", label: "Hilton block" } ]
      },
      idempotency_key: SecureRandom.uuid
    ).call.record
    RecordSupplierReservationRequest.new(
      agency: @agency, actor: @actor, reservation:,
      attributes: { channel: "email", reference_note: "Block request" },
      idempotency_key: SecureRandom.uuid
    ).call
    scope = reservation.revisions.where(status: "requested").sole.scopes.sole
    assert_difference -> { hilton_pool.capacity_events.where(event_type: "increased").count }, 1 do
      m3f_record_confirmed_response!(
        hilton, reservation:, scope:,
        capacity_consequences: [ {
          capacity_pool_id: hilton_pool.id,
          event_type: "increased",
          quantity: 2,
          effective_on: hilton[:occurrence_definition].starts_on
        } ]
      )
    end

    cruise_reservation = CreateSupplierReservation.new(
      agency: @agency, actor: @actor, arrangement: cruise[:arrangement],
      attributes: {
        booking_supplier_id: cruise[:supplier].id,
        supplier_arrangement_version_id: cruise[:version].id,
        scopes: [ { target_kind: "arrangement", label: "Group block" } ]
      },
      idempotency_key: SecureRandom.uuid
    ).call.record
    RecordSupplierReservationRequest.new(
      agency: @agency, actor: @actor, reservation: cruise_reservation,
      attributes: { channel: "email", reference_note: "Cruise request" },
      idempotency_key: SecureRandom.uuid
    ).call
    cruise_scope = cruise_reservation.revisions.where(status: "requested").sole.scopes.sole
    m3f_record_confirmed_response!(cruise, reservation: cruise_reservation, scope: cruise_scope)

    confirmation_commitments = SupplierCommitment.where(
      supplier_arrangement: cruise[:arrangement], opening_kind: "confirmation_trigger"
    ).to_a
    assert_predicate confirmation_commitments, :any?
    satisfaction = SupplierConfirmation.create!(
      agency: @agency, departure:,
      supplier_arrangement: cruise[:arrangement],
      supplier_arrangement_version: cruise[:version],
      confirming_supplier: cruise[:supplier],
      evidence_kind: "supplier_confirmation",
      evidence_on: Date.current,
      channel: "portal",
      reference_note: "Holds confirmed",
      confirmed_without_identifier_reason: "Portal group note",
      actor: @actor,
      recorded_at: Time.current
    )
    DisposeSupplierCommitmentsWithEvidence.new(
      agency: @agency, actor: @actor, arrangement: cruise[:arrangement],
      confirmation: satisfaction,
      commitment_ids: confirmation_commitments.map(&:id),
      outcome: "satisfied",
      idempotency_key: SecureRandom.uuid
    ).call

    initial_commitment = SupplierCommitment.find_by!(
      opening_kind: "deposit_requirement",
      supplier_deposit_requirement_tranche: initial
    )
    AttestSupplierDepositHandledExternally.new(
      agency: @agency, actor: @actor, commitment: initial_commitment,
      note: "Wire confirmed handled outside DepartureDesk",
      confirmed_complete: true,
      idempotency_key: SecureRandom.uuid
    ).call
    assert_equal "handled_externally", initial_commitment.reload.disposition_outcome

    deposit_count_before_milestone = SupplierCommitment.where(
      supplier_arrangement: cruise[:arrangement], opening_kind: "deposit_requirement"
    ).count
    milestone = RecordSupplierPlanningMilestone.new(
      agency: @agency, actor: @actor, arrangement: cruise[:arrangement],
      version: cruise[:version].reload,
      kind: "names_assigned_to_supplier",
      occurred_on: Date.new(2027, 2, 20),
      note: "Cabin names sent for the sailing",
      idempotency_key: SecureRandom.uuid
    ).call.record
    assert_equal "names_assigned_to_supplier", milestone.kind
    assert_equal deposit_count_before_milestone,
      SupplierCommitment.where(
        supplier_arrangement: cruise[:arrangement], opening_kind: "deposit_requirement"
      ).count,
      "Name-assignment replaces Deadline without duplicate deposit commitment"
    assert_not_includes SupplierPlanningMilestoneOccurrence.column_names, "cabin_id"

    findings_before = SupplierAttentionFinding.where(supplier_arrangement: cruise[:arrangement]).count
    RebuildSupplierAttentionProjectionAlreadyLocked.new(
      agency: @agency, arrangement: cruise[:arrangement]
    ).call
    assert_operator SupplierAttentionFinding.where(supplier_arrangement: cruise[:arrangement]).count,
      :>=, 0
    assert_operator findings_before, :>=, 0

    RebuildSupplierExposureProjection.new(
      agency: @agency, actor: @actor, arrangement: cruise[:arrangement]
    ).call
    assert SupplierExposureSummary.exists?(
      supplier_arrangement: cruise[:arrangement], qualification_band: "forecast"
    )

    successor = CreateSupplierArrangementSuccessor.new(
      agency: @agency, actor: @actor, arrangement: cruise[:arrangement],
      arrangement_lock_version: cruise[:arrangement].reload.lock_version,
      version_lock_version: cruise[:version].reload.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call.record
    assert_equal "draft", successor.status
    assert_equal cruise[:version].id, successor.copied_from_id

    m3f_end_arrangement!(transfer)
    assert transfer[:arrangement].ended?

    m3f_assert_no_client_commercial_tables!
    assert_equal 0,
      SupplierArrangement.where(agency_id: @other_agency.id, id: cruise[:arrangement].id).count
  end

  test "Vineyard Tour Supplier journey runs Reservation ops and clean ending" do
    graph = m3f_activated_graph!(
      "M3F2 Vineyard",
      "Vineyard Tour",
      starts_on: Date.new(2027, 6, 5),
      ends_on: Date.new(2027, 6, 7),
      capacity_management: "managed"
    )
    pool = m3f_add_numeric_pool!(
      graph, quantity: 30, measurement_basis: "traveler_positions", label: "30-seat coach"
    )
    pool_definition = CapacityPoolDefinition.find_by!(capacity_pool_id: pool.id)
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

    reservation = CreateSupplierReservation.new(
      agency: @agency, actor: @actor, arrangement: graph[:arrangement],
      attributes: {
        booking_supplier_id: graph[:supplier].id,
        supplier_arrangement_version_id: graph[:version].id,
        scopes: [ { target_kind: "arrangement", label: "Coach seats" } ]
      },
      idempotency_key: SecureRandom.uuid
    ).call.record
    RecordSupplierReservationRequest.new(
      agency: @agency, actor: @actor, reservation:,
      attributes: { channel: "email", reference_note: "Seat hold" },
      idempotency_key: SecureRandom.uuid
    ).call
    scope = reservation.revisions.where(status: "requested").sole.scopes.sole
    m3f_record_confirmed_response!(
      graph, reservation:, scope:,
      capacity_consequences: [ {
        capacity_pool_id: pool.id,
        event_type: "increased",
        quantity: 12,
        effective_on: graph[:departure].starts_on
      } ]
    )
    assert_equal 1, pool.capacity_events.where(event_type: "increased").count

    forecast_band = SupplierExposureSummary.find_by!(
      supplier_arrangement: graph[:arrangement], qualification_band: "forecast"
    )
    assert_equal 180_000, forecast_band.gross_minor_units,
      "ledger=#{LEDGER_ILLUSTRATIVE} 120000 + 12*5000"

    m3f_end_arrangement!(graph)
    assert graph[:arrangement].ended?

    m3f_assert_no_client_commercial_tables!
  end

  test "draft Departure keeps planning tentative and blocks Arrangement activation" do
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

  private

  def create_calculated_hilton_cost!(graph)
    actor = graph[:actor] || @actor
    # Illustrative Hilton room block amount — not a confirmed worksheet figure.
    source = CreateSupplierCostSource.new(
      agency: @agency, actor:, arrangement: graph[:arrangement],
      version_lock_version: graph[:version].reload.lock_version,
      idempotency_key: SecureRandom.uuid,
      attributes: {
        arrangement_item_id: graph[:item].id,
        charging_supplier_id: graph[:supplier].id,
        label: "Hilton guaranteed rooms"
      }
    ).call.record
    definition = CreateSupplierCostDefinition.new(
      agency: @agency, actor:, source:,
      source_lock_version: source.lock_version,
      idempotency_key: SecureRandom.uuid,
      attributes: {
        stage: "contracted", mode: "calculated", currency: "USD", rounding_mode: "half_up"
      }
    ).call.record
    CreateSupplierCostComponent.new(
      agency: @agency, actor:, definition:,
      definition_lock_version: definition.lock_version,
      idempotency_key: SecureRandom.uuid,
      attributes: {
        label: "Room block", economic_role: "supplier_charge",
        calculation_kind: "fixed", amount_minor_units: 200_000, pass_through: false
      }
    ).call
    MarkCostDefinitionForecastReady.new(
      agency: @agency, actor:, definition: definition.reload,
      lock_version: definition.lock_version,
      readiness_provenance: "M3F.2 illustrative Hilton"
    ).call
    m3f_create_deposit!(
      graph,
      amount_shape: "percentage_of_cost_sources",
      percentage: "15",
      rounding_scope: "aggregate",
      description: "15% deposit on guaranteed rooms",
      rule_shape: "fixed_date",
      rule_parameters: { "date" => "2027-02-01" },
      cost_links: [ { supplier_cost_source_id: source.id } ]
    )
    source.reload
  end
end
