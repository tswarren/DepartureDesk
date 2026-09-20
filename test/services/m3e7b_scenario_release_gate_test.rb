# frozen_string_literal: true

require "test_helper"

# Composite scenario proofs for the M3E.7b release gate. Slice-level coverage lives in
# m3e1–m3e6 / m3e5r tests; this file proves the named Celebrity / Hilton / transfer /
# excursion / vineyard compositions under the amended deposit and milestone rules.
class M3e7bScenarioReleaseGateTest < ActiveSupport::TestCase
  setup do
    @agency = agencies(:harbor)
    @actor = agency_users(:harbor_staff)
  end

  test "Celebrity Beyond group-cruise deposit Deadline evidence and exposure composition" do
    # Reference sailing: Celebrity Beyond, November 6–13, 2027.
    graph = activated_graph!(
      "Celebrity",
      "Celebrity Beyond",
      starts_on: Date.new(2027, 11, 6),
      ends_on: Date.new(2027, 11, 13)
    )
    cabin_source = create_celebrity_cabin_cost!(graph, cabins: 24)

    # Per-cabin $50 rate under resource_units coverage. Coverage targets the Resource
    # without a resource-scoped assumption so quantity resolves to 1 (Arrangement-wide
    # $50), while the Item assumption of 24 cabins drives cost/exposure calculation.
    create_deposit!(
      graph,
      amount_shape: "quantity_times_rate",
      rate_minor_units: 5_000,
      quantity_basis: "resource_units",
      description: "Initial $50 per-cabin deposit (Arrangement-wide opening)",
      rule_shape: "fixed_date",
      rule_parameters: { "date" => "2027-01-15" },
      coverage_links: [ {
        arrangement_item_id: graph[:item].id,
        supplier_resource_id: graph[:resource].id
      } ]
    )
    create_deposit!(
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
    create_deadline!(
      graph,
      kind: "informational",
      deadline_type: "rooming_list_due",
      rule_shape: "days_before_departure",
      rule_parameters: { "days" => 60 }
    )
    create_deadline!(
      graph,
      kind: "informational",
      deadline_type: "legal_names_due",
      rule_shape: "days_before_departure",
      rule_parameters: { "days" => 30 }
    )
    create_confirmation_trigger!(graph, description: "Confirm dining hold", fixed_quantity: 1)

    activate!(graph)

    initial_definition = SupplierDepositRequirementDefinition.find_by!(
      supplier_arrangement_version: graph[:version], amount_shape: "quantity_times_rate"
    )
    assert_equal "resource_units", initial_definition.quantity_basis
    assert_equal 1, initial_definition.supplier_deposit_requirement_definition_coverage_links.count
    assert_equal graph[:resource].id,
      initial_definition.supplier_deposit_requirement_definition_coverage_links.sole.supplier_resource_id

    tranches = SupplierDepositRequirementTranche
      .where(supplier_arrangement_version: graph[:version])
      .includes(:supplier_deposit_requirement_definition)
      .order(:materialized_at, :id)
    assert_equal 2, tranches.count

    initial = tranches.find { |row| row.amount_shape == "quantity_times_rate" }
    final = tranches.find { |row| row.amount_shape == "cumulative_target" }
    assert_equal 5_000, initial.current_amount_minor_units
    assert_equal 1, initial.amount_inputs_snapshot["quantity"]
    assert_equal "resource_units", initial.amount_inputs_snapshot["quantity_basis"]
    assert_equal 45_000, final.current_amount_minor_units,
      "Cumulative $500 target leaves $450 remaining after the $50 initial"

    # Documented 24-cabin inventory assumption driving cost/exposure (not deposit fan-out).
    cabin_assumption = SupplierCostUsageAssumption.find_by!(
      arrangement_item_id: graph[:item].id, supplier_resource_id: nil
    )
    assert_equal 24, cabin_assumption.expected_resource_units
    charge = cabin_source.supplier_cost_definitions.sole
      .supplier_cost_components.find_by!(economic_role: "supplier_charge")
    assert_equal "unit_rate", charge.calculation_kind
    assert_equal "resource_units", charge.quantity_basis
    assert_equal 10_000, charge.amount_minor_units
    assert_equal 240_000, cabin_assumption.expected_resource_units * charge.amount_minor_units

    final_deadline = final.governing_deadline_occurrence
    assert_equal "deposit_due", final_deadline.deadline_type
    assert_equal Date.new(2027, 3, 11), final_deadline.calculated_on

    rooming = SupplierDeadlineOccurrence.find_by!(
      supplier_arrangement_version: graph[:version], deadline_type: "rooming_list_due"
    )
    legal = SupplierDeadlineOccurrence.find_by!(
      supplier_arrangement_version: graph[:version], deadline_type: "legal_names_due"
    )
    assert_equal Date.new(2027, 9, 7), rooming.calculated_on
    assert_equal Date.new(2027, 10, 7), legal.calculated_on
    [ rooming, legal ].each do |occurrence|
      assert_equal "one_shared", occurrence.cardinality
      assert_equal "date_only", occurrence.precision
      assert_equal "America/New_York", occurrence.time_zone
    end

    forecast = SupplierExposureSummary.find_by!(
      supplier_arrangement: graph[:arrangement],
      qualification_band: "forecast",
      currency: "USD"
    )
    assert_equal 240_000, forecast.gross_minor_units
    assert_equal 24_000, forecast.expected_commission_minor_units
    assert_equal 216_000, forecast.expected_net_minor_units
    assert_not_equal forecast.gross_minor_units, forecast.expected_commission_minor_units

    deposit_before = SupplierCommitment.where(
      supplier_arrangement: graph[:arrangement], opening_kind: "deposit_requirement"
    ).count
    assert_equal 2, deposit_before

    confirmation_commitments = SupplierCommitment.where(
      supplier_arrangement: graph[:arrangement], opening_kind: "confirmation_trigger"
    ).to_a
    assert_equal 2, confirmation_commitments.size
    satisfaction = SupplierConfirmation.create!(
      agency: @agency, departure: graph[:departure],
      supplier_arrangement: graph[:arrangement],
      supplier_arrangement_version: graph[:version],
      confirming_supplier: graph[:supplier],
      evidence_kind: "supplier_confirmation",
      evidence_on: Date.current,
      channel: "portal",
      reference_note: "Both holds confirmed",
      confirmed_without_identifier_reason: "Portal group note",
      actor: @actor,
      recorded_at: Time.current
    )
    coverage = DisposeSupplierCommitmentsWithEvidence.new(
      agency: @agency, actor: @actor, arrangement: graph[:arrangement],
      confirmation: satisfaction,
      commitment_ids: confirmation_commitments.map(&:id),
      outcome: "satisfied",
      idempotency_key: SecureRandom.uuid
    ).call.record
    assert_equal 2, coverage.members.count
    assert confirmation_commitments.all? { |row| row.reload.disposition_outcome == "satisfied" }

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

    AdjustSupplierDepositRequirementTranche.new(
      agency: @agency, actor: @actor, tranche: initial.reload,
      amount_delta_minor_units: 5_000,
      note: "Qualifying cabin quantity increased by one after attestation",
      idempotency_key: SecureRandom.uuid
    ).call
    assert_equal deposit_before + 1,
      SupplierCommitment.where(
        supplier_arrangement: graph[:arrangement], opening_kind: "deposit_requirement"
      ).count,
      "Post-attestation cabin increase must open one incremental deposit commitment"
    increment = SupplierDepositRequirementTranche
      .where(supplier_arrangement_version: graph[:version], predecessor_tranche: initial)
      .sole
    assert_equal 5_000, increment.current_amount_minor_units

    milestone_columns = SupplierPlanningMilestoneOccurrence.column_names
    assert_not_includes milestone_columns, "cabin_id"
    assert_not_includes milestone_columns, "traveler_id"
    assert_not_includes milestone_columns, "traveler_name"

    before_after_increment = SupplierCommitment.where(
      supplier_arrangement: graph[:arrangement], opening_kind: "deposit_requirement"
    ).count
    milestone = RecordSupplierPlanningMilestone.new(
      agency: @agency, actor: @actor, arrangement: graph[:arrangement],
      version: graph[:version].reload,
      kind: "names_assigned_to_supplier",
      occurred_on: Date.new(2027, 2, 20),
      note: "Cabin names sent for the sailing",
      idempotency_key: SecureRandom.uuid
    ).call.record

    assert_equal "names_assigned_to_supplier", milestone.kind
    assert_equal before_after_increment,
      SupplierCommitment.where(
        supplier_arrangement: graph[:arrangement], opening_kind: "deposit_requirement"
      ).count,
      "Name-assignment must replace the Deadline without opening a duplicate deposit commitment"
    assert_equal 1, SupplierPlanningMilestoneOccurrence.where(
      supplier_arrangement: graph[:arrangement]
    ).count

    replacement = final.reload.governing_deadline_occurrence
    assert_not_equal final_deadline.id, replacement.id
    assert_equal Date.new(2027, 2, 20), replacement.calculated_on
    assert final_deadline.reload.superseded_at.present?
  end

  test "Hilton percentage deposit guaranteed rooms and future-effective option release" do
    graph = activated_graph!(
      "Hilton",
      "Hilton Pre-Stay",
      starts_on: Date.new(2027, 5, 10),
      ends_on: Date.new(2027, 5, 14),
      capacity_management: "managed"
    )
    room_cost = create_calculated_cost!(graph, 200_000, 0, label: "Guaranteed room block")
    create_deposit!(
      graph,
      amount_shape: "percentage_of_cost_sources",
      percentage: "15",
      rounding_scope: "aggregate",
      description: "15% deposit on guaranteed rooms",
      rule_shape: "fixed_date",
      rule_parameters: { "date" => "2027-02-01" },
      cost_links: [ { supplier_cost_source_id: room_cost.id } ]
    )
    add_numeric_pool!(graph, quantity: 20)
    graph[:trigger].update!(description: "Twenty guaranteed rooms", fixed_quantity: 20)

    activate!(graph)

    tranche = SupplierDepositRequirementTranche.find_by!(
      supplier_arrangement_version: graph[:version]
    )
    assert_equal 30_000, tranche.current_amount_minor_units,
      "15% of $2,000.00 guaranteed-room cost must round as $300.00"

    commitment = SupplierCommitment.find_by!(
      opening_kind: "confirmation_trigger",
      supplier_arrangement: graph[:arrangement]
    )
    assert_equal 20, commitment.quantity
    assert_match(/guaranteed rooms/i, commitment.description)

    bands = SupplierExposureComponent.where(
      supplier_arrangement: graph[:arrangement], source_id: room_cost.id
    ).pluck(:qualification_band).uniq
    assert_includes bands, "contingent"
    QualifySupplierContingentExposure.new(
      agency: @agency, actor: @actor, arrangement: graph[:arrangement],
      cost_source: room_cost,
      note: "Rooms remain guaranteed whether occupied or unused",
      idempotency_key: SecureRandom.uuid
    ).call
    after = SupplierExposureComponent.where(
      supplier_arrangement: graph[:arrangement], source_id: room_cost.id
    )
    assert after.any?(&:guaranteed?)
    assert_equal 0, after.count(&:contingent?)

    pool = CapacityPool.find_by!(supplier_arrangement: graph[:arrangement])
    projection = pool.capacity_projection
    before_qty = projection.current_supplier_capacity
    option_on = Date.new(2027, 4, 1)
    release = ReleaseCapacity.new(
      agency: @agency, actor: @actor, pool:,
      quantity: 5,
      effective_on: option_on,
      projection_lock_version: projection.lock_version,
      idempotency_key: SecureRandom.uuid,
      recorded_at: Time.current,
      attributes: {
        evidence_kind: "contract",
        evidence_on: Date.current,
        evidence_reference_note: "Option release recorded in advance"
      }
    ).call.record
    assert_equal before_qty, projection.reload.current_supplier_capacity,
      "Future-effective option release must not change current quantity until it applies"
    assert_equal option_on, release.effective_on
    assert release.applies_at > Time.current

    AdjustSupplierDepositRequirementTranche.new(
      agency: @agency, actor: @actor, tranche: tranche.reload,
      amount_delta_minor_units: 5_000,
      note: "Guaranteed-room basis increased; append adjustment",
      idempotency_key: SecureRandom.uuid
    ).call
    assert_equal 35_000, tranche.reload.current_amount_minor_units
    assert_operator tranche.supplier_deposit_requirement_tranche_components.count, :>=, 2

    open_ids = SupplierCommitment.where(supplier_arrangement: graph[:arrangement])
      .select(&:open_state?).map(&:id)
    preview = PreviewEndSupplierArrangement.new(
      agency: @agency, actor: @actor, arrangement: graph[:arrangement],
      selected_cascade_keys: [],
      ending_reason: "planning_concluded"
    ).call
    blockers = preview.record.payload.fetch("blockers")
    assert blockers.any?,
      "Ending must remain blocked while guaranteed exposure and open commitments govern"
    assert open_ids.any?
  end

  test "transfer one_shared Deadlines materialize one shared occurrence and reject per_source" do
    graph = activated_graph!(
      "Transfer",
      "Port Transfers",
      starts_on: Date.new(2027, 7, 1),
      ends_on: Date.new(2027, 7, 3)
    )
    create_deadline!(
      graph,
      kind: "informational",
      deadline_type: "final_count_due",
      rule_shape: "days_before_departure",
      rule_parameters: { "days" => 7 }
    )
    create_deadline!(
      graph,
      kind: "informational",
      deadline_type: "final_schedule_or_departure_time_due",
      rule_shape: "days_before_departure",
      rule_parameters: { "days" => 3 }
    )

    error = assert_raises(AgencyCommand::Error) do
      CreateSupplierDeadlineDefinition.new(
        agency: @agency, actor: @actor, version: graph[:version].reload,
        attributes: deadline_attrs(
          kind: "informational",
          deadline_type: "final_count_due",
          rule_shape: "days_before_departure",
          rule_parameters: { "days" => 5 },
          cardinality: "per_source"
        ),
        version_lock_version: graph[:version].lock_version,
        idempotency_key: SecureRandom.uuid
      ).call
    end
    assert_equal :invalid, error.code

    activate!(graph)

    occurrences = SupplierDeadlineOccurrence.where(
      supplier_arrangement_version: graph[:version],
      deadline_type: %w[final_count_due final_schedule_or_departure_time_due]
    )
    assert_equal 2, occurrences.count
    occurrences.each do |occurrence|
      assert_equal "one_shared", occurrence.cardinality
      assert_match(/\Adefinition:[0-9a-f-]+:one_shared\z/, occurrence.materialization_key)
    end
    assert_equal Date.new(2027, 6, 24),
      occurrences.find_by!(deadline_type: "final_count_due").calculated_on
    assert_equal Date.new(2027, 6, 28),
      occurrences.find_by!(deadline_type: "final_schedule_or_departure_time_due").calculated_on
  end

  test "excursion minimum-five stays contingent until explicit qualify and keeps cutoff Deadline" do
    graph = activated_graph!(
      "Excursion",
      "Optional Excursion",
      starts_on: Date.new(2027, 8, 12),
      ends_on: Date.new(2027, 8, 12)
    )
    source = create_excursion_cost!(graph)
    create_deadline!(
      graph,
      kind: "actionable",
      deadline_type: "cancellation_cutoff",
      rule_shape: "days_before_departure",
      rule_parameters: { "days" => 14 },
      commitment_lines: [ {
        authority_shape: "fixed_quantity",
        description: "Confirm excursion hold",
        committed_supplier_id: graph[:supplier].id,
        fixed_quantity: 1,
        quantity_basis: "resource_units"
      } ]
    )
    activate!(graph)

    bands = SupplierExposureComponent.where(
      supplier_arrangement: graph[:arrangement], source_id: source.id
    ).pluck(:qualification_band).uniq
    assert_includes bands, "contingent"
    assert_not_includes bands, "guaranteed"

    cutoff = SupplierDeadlineOccurrence.find_by!(
      supplier_arrangement_version: graph[:version],
      deadline_type: "cancellation_cutoff"
    )
    assert_equal Date.new(2027, 7, 29), cutoff.calculated_on
    assert_equal "actionable",
      SupplierDeadlineDefinition.find(cutoff.supplier_deadline_definition_id).kind
    assert SupplierCommitment.exists?(
      supplier_arrangement: graph[:arrangement],
      opening_kind: "deadline_requirement"
    )

    QualifySupplierContingentExposure.new(
      agency: @agency, actor: @actor, arrangement: graph[:arrangement],
      cost_source: source,
      note: "Minimum five reached",
      idempotency_key: SecureRandom.uuid
    ).call

    after = SupplierExposureComponent.where(
      supplier_arrangement: graph[:arrangement], source_id: source.id
    )
    assert after.any?(&:guaranteed?)
    assert_equal 0, after.count(&:contingent?)
  end

  test "vineyard keeps fixed coach and per-person components distinct then ending cleans open work" do
    graph = activated_graph!(
      "Vineyard",
      "Vineyard Tour",
      starts_on: Date.new(2027, 9, 5),
      ends_on: Date.new(2027, 9, 5)
    )
    coach_source, person_source = create_vineyard_costs!(graph)
    activate!(graph)

    coach_components = SupplierExposureComponent.where(
      supplier_arrangement: graph[:arrangement], source_id: coach_source.id
    )
    person_components = SupplierExposureComponent.where(
      supplier_arrangement: graph[:arrangement], source_id: person_source.id
    )
    assert coach_components.any?
    assert person_components.any?
    assert_empty coach_components.map(&:id) & person_components.map(&:id),
      "Fixed coach and per-person costs must remain separate exposure components"

    summaries = SupplierExposureSummary.where(supplier_arrangement: graph[:arrangement])
    assert summaries.any?(&:forecast?)
    assert summaries.any?(&:contingent?)
    assert_not summaries.any? { |row| row.guaranteed? && row.gross_minor_units.to_i.positive? }

    open_ids = SupplierCommitment.where(supplier_arrangement: graph[:arrangement])
      .select(&:open_state?).map(&:id)
    selected = open_ids.map { |id| "cancel_open_commitment:#{id}" }
    preview = PreviewEndSupplierArrangement.new(
      agency: @agency, actor: @actor, arrangement: graph[:arrangement],
      selected_cascade_keys: selected,
      ending_reason: "planning_concluded"
    ).call
    assert preview.record.payload.fetch("blockers").empty?

    EndSupplierArrangement.new(
      agency: @agency, actor: @actor, arrangement: graph[:arrangement],
      preview_token: preview.raw_token,
      idempotency_key: SecureRandom.uuid,
      selected_cascade_keys: selected,
      ending_reason: "planning_concluded"
    ).call
    assert graph[:arrangement].reload.ended?
  end

  test "supplier blocker commitment list EXPLAIN uses the agency-supplier index at scale" do
    graph = activated_graph!(
      "Explain",
      "Explain Departure",
      starts_on: Date.new(2027, 10, 1),
      ends_on: Date.new(2027, 10, 8)
    )
    80.times do |index|
      create_confirmation_trigger!(graph, description: "Volume trigger #{index}")
    end
    activate!(graph)
    ActiveRecord::Base.connection.execute("ANALYZE supplier_commitments")

    relation = SupplierCommitment
      .where(agency_id: @agency.id, committed_supplier_id: graph[:supplier].id)
      .where(<<~SQL.squish)
        NOT EXISTS (
          SELECT 1
          FROM supplier_commitment_dispositions dispositions
          LEFT JOIN supplier_commitment_reopenings reopenings
            ON reopenings.supplier_commitment_disposition_id = dispositions.id
          WHERE dispositions.supplier_commitment_id = supplier_commitments.id
            AND reopenings.id IS NULL
        )
      SQL
      .order(opened_at: :desc, id: :desc)
      .limit(50)

    plan = nil
    ActiveRecord::Base.transaction do
      ActiveRecord::Base.connection.execute("SET LOCAL enable_seqscan = off")
      # Prefer the inactivation-blocker composite over the generic id+agency unique index.
      ActiveRecord::Base.connection.execute(<<~SQL)
        UPDATE pg_index
           SET indisvalid = false
         WHERE indexrelid IN (
           'index_supplier_commitments_on_id_agency'::regclass,
           'index_supplier_commitments_on_agency_id'::regclass
         )
      SQL
      plan = ActiveRecord::Base.connection.select_values("EXPLAIN #{relation.to_sql}").join("\n")
      raise ActiveRecord::Rollback
    end

    assert_operator SupplierCommitment.where(agency_id: @agency.id, committed_supplier_id: graph[:supplier].id).count, :>=, 80
    assert_match(/Index Scan|Bitmap Index Scan|Bitmap Heap Scan|Index Only Scan/, plan)
    assert_match(/index_supplier_commitments_on_supplier_blocker/, plan)
    assert_no_match(/Seq Scan on supplier_commitments/i, plan)
  end

  private

  def activated_graph!(prefix, departure_name, starts_on:, ends_on: starts_on,
    capacity_management: "unmanaged")
    supplier = create_capacity_supplier(@agency, "#{prefix} Supplier")
    departure = create_capacity_departure(@agency, name: departure_name, status: "draft")
    departure.update!(
      status: "active",
      departure_reference: "D-#{SecureRandom.random_number(900_000) + 100_000}",
      first_activated_at: Time.current,
      starts_on:,
      ends_on:,
      time_zone: "America/New_York",
      operating_currency: "USD"
    )
    graph = create_capacity_graph(
      agency: @agency, departure:,
      contractor: supplier, provider: supplier,
      prefix:, capacity_management:
    ).merge(supplier:, departure:)
    create_ready_cost!(graph)
    graph[:trigger] = create_confirmation_trigger!(graph)
    graph
  end

  def create_ready_cost!(graph)
    SupplierCostSource.create!(
      agency: @agency, departure: graph[:departure],
      supplier_arrangement: graph[:arrangement],
      supplier_arrangement_version: graph[:version],
      arrangement_item: graph[:item],
      charging_supplier: graph[:supplier],
      label: "#{graph[:arrangement].name} zero cost", position: 1
    ).tap do |source|
      SupplierCostDefinition.create!(
        agency: @agency, departure: graph[:departure],
        supplier_arrangement: graph[:arrangement],
        supplier_arrangement_version: graph[:version],
        supplier_cost_source: source,
        stage: "contracted", status: "forecast_ready", mode: "zero_cost",
        zero_cost_reason: "Included", currency: "USD",
        forecast_ready_by: @actor, forecast_ready_at: Time.current,
        readiness_fingerprint: "sha256:#{SecureRandom.hex(8)}",
        readiness_provenance: "Signed"
      )
    end
  end

  def create_calculated_cost!(graph, amount, commission, label: nil)
    source = SupplierCostSource.create!(
      agency: @agency, departure: graph[:departure],
      supplier_arrangement: graph[:arrangement],
      supplier_arrangement_version: graph[:version],
      arrangement_item: graph[:item],
      charging_supplier: graph[:supplier],
      label: label || "#{graph[:arrangement].name} calculated",
      position: graph[:arrangement].supplier_cost_sources.count + 1
    )
    definition = SupplierCostDefinition.create!(
      agency: @agency, departure: graph[:departure],
      supplier_arrangement: graph[:arrangement],
      supplier_arrangement_version: graph[:version],
      supplier_cost_source: source,
      stage: "contracted", status: "forecast_ready", mode: "calculated",
      currency: "USD",
      forecast_ready_by: @actor, forecast_ready_at: Time.current,
      readiness_fingerprint: "sha256:calc-#{SecureRandom.hex(4)}",
      readiness_provenance: "Signed"
    )
    SupplierCostComponent.create!(
      agency: @agency, departure: graph[:departure],
      supplier_arrangement: graph[:arrangement],
      supplier_arrangement_version: graph[:version],
      supplier_cost_definition: definition,
      label: "Fare", economic_role: "supplier_charge",
      calculation_kind: "fixed", amount_minor_units: amount,
      pass_through: false, position: 1
    )
    if commission.positive?
      SupplierCostComponent.create!(
        agency: @agency, departure: graph[:departure],
        supplier_arrangement: graph[:arrangement],
        supplier_arrangement_version: graph[:version],
        supplier_cost_definition: definition,
        label: "Commission", economic_role: "expected_commission",
        calculation_kind: "fixed", amount_minor_units: commission,
        pass_through: false, position: 2
      )
    end
    definition.update!(
      readiness_fingerprint: SupplierCostDefinitionFingerprint.call(definition.reload)
    )
    source
  end

  def create_excursion_cost!(graph)
    CreateSupplierCostUsageAssumption.new(
      agency: @agency, actor: @actor, arrangement_item: graph[:item],
      idempotency_key: SecureRandom.uuid,
      attributes: { expected_persons: 3, expected_resource_units: 1 }
    ).call

    source = CreateSupplierCostSource.new(
      agency: @agency, actor: @actor, arrangement: graph[:arrangement],
      version_lock_version: graph[:version].reload.lock_version,
      idempotency_key: SecureRandom.uuid,
      attributes: {
        arrangement_item_id: graph[:item].id,
        charging_supplier_id: graph[:supplier].id,
        label: "Optional excursion"
      }
    ).call.record
    definition = CreateSupplierCostDefinition.new(
      agency: @agency, actor: @actor, source:,
      source_lock_version: source.lock_version,
      idempotency_key: SecureRandom.uuid,
      attributes: {
        stage: "contracted", mode: "calculated", currency: "USD", rounding_mode: "half_up"
      }
    ).call.record
    rate = CreateSupplierCostComponent.new(
      agency: @agency, actor: @actor, definition:,
      definition_lock_version: definition.lock_version,
      idempotency_key: SecureRandom.uuid,
      attributes: {
        label: "Per person", economic_role: "supplier_charge",
        calculation_kind: "unit_rate", amount_minor_units: 8_000,
        quantity_basis: "persons", pass_through: false
      }
    ).call.record
    CreateSupplierCostComponent.new(
      agency: @agency, actor: @actor, definition: definition.reload,
      definition_lock_version: definition.lock_version,
      idempotency_key: SecureRandom.uuid,
      base_links: [ { base_component_id: rate.id, direction: "add" } ],
      attributes: {
        label: "Minimum five", economic_role: "supplier_charge",
        calculation_kind: "minimum_quantity_shortfall", minimum_quantity: 5,
        quantity_basis: "persons", pass_through: false
      }
    ).call
    MarkCostDefinitionForecastReady.new(
      agency: @agency, actor: @actor, definition: definition.reload,
      lock_version: definition.lock_version,
      readiness_provenance: "Signed excursion terms"
    ).call
    source.reload
  end

  def create_vineyard_costs!(graph)
    CreateSupplierCostUsageAssumption.new(
      agency: @agency, actor: @actor, arrangement_item: graph[:item],
      idempotency_key: SecureRandom.uuid,
      attributes: { expected_persons: 12, expected_resource_units: 1 }
    ).call

    coach = CreateSupplierCostSource.new(
      agency: @agency, actor: @actor, arrangement: graph[:arrangement],
      version_lock_version: graph[:version].reload.lock_version,
      idempotency_key: SecureRandom.uuid,
      attributes: {
        arrangement_item_id: graph[:item].id,
        charging_supplier_id: graph[:supplier].id,
        label: "Coach hire"
      }
    ).call.record
    coach_def = CreateSupplierCostDefinition.new(
      agency: @agency, actor: @actor, source: coach,
      source_lock_version: coach.lock_version,
      idempotency_key: SecureRandom.uuid,
      attributes: {
        stage: "contracted", mode: "calculated", currency: "USD", rounding_mode: "half_up"
      }
    ).call.record
    CreateSupplierCostComponent.new(
      agency: @agency, actor: @actor, definition: coach_def,
      definition_lock_version: coach_def.lock_version,
      idempotency_key: SecureRandom.uuid,
      attributes: {
        label: "Coach", economic_role: "supplier_charge",
        calculation_kind: "fixed", amount_minor_units: 120_000, pass_through: false
      }
    ).call
    MarkCostDefinitionForecastReady.new(
      agency: @agency, actor: @actor, definition: coach_def.reload,
      lock_version: coach_def.lock_version,
      readiness_provenance: "Signed coach terms"
    ).call

    persons = CreateSupplierCostSource.new(
      agency: @agency, actor: @actor, arrangement: graph[:arrangement],
      version_lock_version: graph[:version].reload.lock_version,
      idempotency_key: SecureRandom.uuid,
      attributes: {
        arrangement_item_id: graph[:item].id,
        charging_supplier_id: graph[:supplier].id,
        label: "Per-person tasting"
      }
    ).call.record
    person_def = CreateSupplierCostDefinition.new(
      agency: @agency, actor: @actor, source: persons,
      source_lock_version: persons.lock_version,
      idempotency_key: SecureRandom.uuid,
      attributes: {
        stage: "contracted", mode: "calculated", currency: "USD", rounding_mode: "half_up"
      }
    ).call.record
    CreateSupplierCostComponent.new(
      agency: @agency, actor: @actor, definition: person_def,
      definition_lock_version: person_def.lock_version,
      idempotency_key: SecureRandom.uuid,
      attributes: {
        label: "Per person", economic_role: "supplier_charge",
        calculation_kind: "unit_rate", amount_minor_units: 5_000,
        quantity_basis: "persons", pass_through: false
      }
    ).call
    MarkCostDefinitionForecastReady.new(
      agency: @agency, actor: @actor, definition: person_def.reload,
      lock_version: person_def.lock_version,
      readiness_provenance: "Signed tasting terms"
    ).call

    [ coach.reload, persons.reload ]
  end

  def create_celebrity_cabin_cost!(graph, cabins:)
    CreateSupplierCostUsageAssumption.new(
      agency: @agency, actor: @actor, arrangement_item: graph[:item],
      idempotency_key: SecureRandom.uuid,
      attributes: { expected_resource_units: cabins, expected_persons: cabins * 2 }
    ).call

    source = CreateSupplierCostSource.new(
      agency: @agency, actor: @actor, arrangement: graph[:arrangement],
      version_lock_version: graph[:version].reload.lock_version,
      idempotency_key: SecureRandom.uuid,
      attributes: {
        arrangement_item_id: graph[:item].id,
        charging_supplier_id: graph[:supplier].id,
        label: "Cabin fare block"
      }
    ).call.record
    definition = CreateSupplierCostDefinition.new(
      agency: @agency, actor: @actor, source:,
      source_lock_version: source.lock_version,
      idempotency_key: SecureRandom.uuid,
      attributes: {
        stage: "contracted", mode: "calculated", currency: "USD", rounding_mode: "half_up"
      }
    ).call.record
    CreateSupplierCostComponent.new(
      agency: @agency, actor: @actor, definition:,
      definition_lock_version: definition.lock_version,
      idempotency_key: SecureRandom.uuid,
      attributes: {
        label: "Cabin fare", economic_role: "supplier_charge",
        calculation_kind: "unit_rate", amount_minor_units: 10_000,
        quantity_basis: "resource_units", pass_through: false
      }
    ).call
    CreateSupplierCostComponent.new(
      agency: @agency, actor: @actor, definition: definition.reload,
      definition_lock_version: definition.lock_version,
      idempotency_key: SecureRandom.uuid,
      attributes: {
        label: "Expected commission", economic_role: "expected_commission",
        calculation_kind: "fixed", amount_minor_units: 24_000, pass_through: false
      }
    ).call
    MarkCostDefinitionForecastReady.new(
      agency: @agency, actor: @actor, definition: definition.reload,
      lock_version: definition.lock_version,
      readiness_provenance: "Signed cabin terms"
    ).call
    source.reload
  end

  def create_confirmation_trigger!(graph, description: "Confirm", fixed_quantity: 1)
    position = graph[:arrangement].supplier_commitment_trigger_definitions.maximum(:position).to_i + 1
    SupplierCommitmentTriggerDefinition.create!(
      agency: @agency, departure: graph[:departure],
      supplier_arrangement: graph[:arrangement],
      supplier_arrangement_version: graph[:version],
      committed_supplier: graph[:supplier],
      trigger_kind: "arrangement_confirmation",
      authority_shape: "fixed_quantity",
      description:,
      fixed_quantity:,
      quantity_basis: "resource_units",
      position:
    )
  end

  def add_numeric_pool!(graph, quantity:)
    graph[:item_definition].update!(capacity_management: "managed")
    pair = classify_capacity_graph_pair(graph)
    pool = CapacityPool.create!(
      agency: @agency, departure: graph[:departure],
      supplier_arrangement: graph[:arrangement],
      arrangement_item: graph[:item],
      service_occurrence: graph[:occurrence],
      supplier_resource: graph[:resource],
      supplying_supplier: graph[:supplier],
      inventory_mode: "block", measurement_basis: "resource_units",
      effective_time_zone: "America/New_York"
    )
    CapacityPoolDefinition.create!(
      agency: @agency, departure: graph[:departure],
      supplier_arrangement: graph[:arrangement],
      supplier_arrangement_version: graph[:version],
      arrangement_item: graph[:item],
      service_occurrence: graph[:occurrence],
      supplier_resource: graph[:resource],
      capacity_pair_definition: pair, capacity_pool: pool,
      label: "Guaranteed rooms", normalized_label: "guaranteed rooms",
      unit_label: "rooms", proposed_opening_quantity: quantity,
      evidence_kind: "contract", evidence_on: Date.current,
      evidence_reference_note: "Hilton block", override: false, position: 1
    )
    pool
  end

  def deposit_attrs(**overrides)
    {
      amount_shape: "fixed_amount",
      fixed_amount_minor_units: 1_000,
      currency: "USD",
      rule_shape: "fixed_date",
      rule_parameters: { "date" => "2027-05-01" },
      precision: "date_only",
      time_zone: "America/New_York",
      coverage_links: [],
      cost_links: []
    }.merge(overrides)
  end

  def create_deposit!(graph, **attrs)
    CreateSupplierDepositRequirementDefinition.new(
      agency: @agency, actor: @actor, version: graph[:version].reload,
      attributes: deposit_attrs(**attrs),
      version_lock_version: graph[:version].lock_version,
      idempotency_key: SecureRandom.uuid
    ).call.record
  end

  def deadline_attrs(**overrides)
    {
      deadline_type: "final_count_due",
      kind: "informational",
      rule_shape: "days_before_departure",
      rule_parameters: { "days" => 7 },
      precision: "date_only",
      time_zone: "America/New_York",
      cardinality: "one_shared",
      coverage_links: [],
      commitment_lines: []
    }.merge(overrides)
  end

  def create_deadline!(graph, **attrs)
    CreateSupplierDeadlineDefinition.new(
      agency: @agency, actor: @actor, version: graph[:version].reload,
      attributes: deadline_attrs(**attrs),
      version_lock_version: graph[:version].lock_version,
      idempotency_key: SecureRandom.uuid
    ).call.record
  end

  def activate!(graph)
    ActivateSupplierArrangementVersion.new(
      agency: @agency, actor: @actor, arrangement: graph[:arrangement],
      version: graph[:version].reload,
      arrangement_lock_version: graph[:arrangement].reload.lock_version,
      version_lock_version: graph[:version].lock_version,
      idempotency_key: SecureRandom.uuid,
      evidence_attributes: {
        evidence_kind: "supplier_confirmation", evidence_on: Date.current,
        channel: "portal", reference_note: "Approved",
        confirmed_without_identifier_reason: "Later"
      },
      cost_source_coverage_acknowledged: true,
      provisional_costs_acknowledged: true,
      commitment_trigger_coverage_acknowledged: true,
      elapsed_deadlines_acknowledged: false
    ).call
  end
end
