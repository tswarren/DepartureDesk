# frozen_string_literal: true

require "test_helper"

class M3e7bScenarioReleaseGateTest < ActiveSupport::TestCase
  setup do
    @agency = agencies(:harbor)
    @actor = agency_users(:harbor_staff)
  end

  test "Celebrity Arrangement-wide deposit and milestone do not imply per-cabin progress" do
    graph = activated_graph!("Celebrity", "Celebrity Beyond")
    create_deposit!(graph, amount: 5_000, date: "2027-01-15")
    create_deposit!(graph, amount_shape: "cumulative_target", target: 50_000, date: "2027-03-11")
    activate!(graph)

    commitments = SupplierCommitment.where(
      supplier_arrangement: graph[:arrangement], opening_kind: "deposit_requirement"
    )
    assert_equal 2, commitments.count
    assert commitments.all? { |row|
      row.supplier_deposit_requirement_tranche_id.present?
    }

    milestone = RecordSupplierPlanningMilestone.new(
      agency: @agency, actor: @actor, arrangement: graph[:arrangement],
      version: graph[:version].reload,
      kind: "names_assigned_to_supplier",
      occurred_on: Date.current,
      note: "Names for the sailing",
      idempotency_key: SecureRandom.uuid
    ).call.record
    assert_equal "names_assigned_to_supplier", milestone.kind
    assert_nil milestone.try(:cabin_id)
    assert_equal 1, SupplierPlanningMilestoneOccurrence.where(
      supplier_arrangement: graph[:arrangement]
    ).count
  end

  test "transfer scenario proves one_shared Deadlines and rejects per_source" do
    graph = activated_graph!("Transfer", "Port Transfers")
    definition = CreateSupplierDeadlineDefinition.new(
      agency: @agency, actor: @actor, version: graph[:version].reload,
      attributes: {
        deadline_type: "final_count_due",
        kind: "informational",
        rule_shape: "days_before_departure",
        rule_parameters: { "days" => 7 },
        precision: "date_only",
        time_zone: "America/New_York",
        cardinality: "one_shared",
        coverage_links: [],
        commitment_lines: []
      },
      version_lock_version: graph[:version].lock_version,
      idempotency_key: SecureRandom.uuid
    ).call.record
    assert_equal "one_shared", definition.cardinality

    error = assert_raises(AgencyCommand::Error) do
      CreateSupplierDeadlineDefinition.new(
        agency: @agency, actor: @actor, version: graph[:version].reload,
        attributes: {
          deadline_type: "final_schedule_or_departure_time_due",
          kind: "informational",
          rule_shape: "days_before_departure",
          rule_parameters: { "days" => 3 },
          precision: "date_only",
          time_zone: "America/New_York",
          cardinality: "per_source",
          coverage_links: [],
          commitment_lines: []
        },
        version_lock_version: graph[:version].lock_version,
        idempotency_key: SecureRandom.uuid
      ).call
    end
    assert_equal :invalid, error.code
  end

  test "excursion contingent cost requires explicit qualification before guaranteed" do
    graph = activated_graph!("Excursion", "Optional Excursion")
    source = create_calculated_cost!(graph, 80_000, 8_000)
    activate!(graph)

    bands = SupplierExposureComponent.where(
      supplier_arrangement: graph[:arrangement], source_id: source.id
    ).pluck(:qualification_band).uniq
    assert_includes bands, "contingent"
    assert_not_includes bands, "guaranteed"

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

  test "vineyard coach and per-person exposure bands stay distinct then ending cleans open work" do
    graph = activated_graph!("Vineyard", "Vineyard Tour")
    create_calculated_cost!(graph, 120_000, 12_000)
    activate!(graph)

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

  private

  def activated_graph!(prefix, departure_name)
    supplier = create_capacity_supplier(@agency, "#{prefix} Supplier")
    departure = create_capacity_departure(@agency, name: departure_name, status: "draft")
    departure.update!(
      status: "active",
      departure_reference: "D-#{SecureRandom.random_number(900_000) + 100_000}",
      first_activated_at: Time.current,
      starts_on: Date.new(2027, 6, 15),
      ends_on: Date.new(2027, 6, 22),
      time_zone: "America/New_York",
      operating_currency: "USD"
    )
    graph = create_capacity_graph(
      agency: @agency, departure:,
      contractor: supplier, provider: supplier,
      prefix:, capacity_management: "unmanaged"
    ).merge(supplier:, departure:)
    create_ready_cost!(graph)
    create_confirmation_trigger!(graph)
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

  def create_calculated_cost!(graph, amount, commission)
    source = SupplierCostSource.create!(
      agency: @agency, departure: graph[:departure],
      supplier_arrangement: graph[:arrangement],
      supplier_arrangement_version: graph[:version],
      arrangement_item: graph[:item],
      charging_supplier: graph[:supplier],
      label: "#{graph[:arrangement].name} calculated", position: 2
    )
    definition = SupplierCostDefinition.create!(
      agency: @agency, departure: graph[:departure],
      supplier_arrangement: graph[:arrangement],
      supplier_arrangement_version: graph[:version],
      supplier_cost_source: source,
      stage: "contracted", status: "forecast_ready", mode: "calculated",
      currency: "USD",
      forecast_ready_by: @actor, forecast_ready_at: Time.current,
      readiness_fingerprint: "sha256:calc",
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
    SupplierCostComponent.create!(
      agency: @agency, departure: graph[:departure],
      supplier_arrangement: graph[:arrangement],
      supplier_arrangement_version: graph[:version],
      supplier_cost_definition: definition,
      label: "Commission", economic_role: "expected_commission",
      calculation_kind: "fixed", amount_minor_units: commission,
      pass_through: false, position: 2
    )
    definition.update!(
      readiness_fingerprint: SupplierCostDefinitionFingerprint.call(definition.reload)
    )
    source
  end

  def create_confirmation_trigger!(graph)
    SupplierCommitmentTriggerDefinition.create!(
      agency: @agency, departure: graph[:departure],
      supplier_arrangement: graph[:arrangement],
      supplier_arrangement_version: graph[:version],
      committed_supplier: graph[:supplier],
      trigger_kind: "arrangement_confirmation",
      authority_shape: "fixed_quantity",
      description: "Confirm",
      fixed_quantity: 1,
      quantity_basis: "resource_units",
      position: 1
    )
  end

  def create_deposit!(graph, amount: nil, amount_shape: "fixed_amount", target: nil, date:)
    attrs = {
      amount_shape:,
      currency: "USD",
      rule_shape: "fixed_date",
      rule_parameters: { "date" => date },
      precision: "date_only",
      time_zone: "America/New_York",
      coverage_links: [],
      cost_links: []
    }
    if amount_shape == "cumulative_target"
      attrs[:target_amount_minor_units] = target
    else
      attrs[:fixed_amount_minor_units] = amount
    end
    CreateSupplierDepositRequirementDefinition.new(
      agency: @agency, actor: @actor, version: graph[:version].reload,
      attributes: attrs,
      version_lock_version: graph[:version].lock_version,
      idempotency_key: SecureRandom.uuid
    ).call
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
