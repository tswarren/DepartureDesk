# frozen_string_literal: true

require "test_helper"

class M3e2DeadlineDefinitionsOccurrencesTest < ActiveSupport::TestCase
  setup do
    @agency = agencies(:harbor)
    @actor = agency_users(:harbor_staff)
    @supplier = create_capacity_supplier(@agency, "Deadline Supplier")
    @departure = create_capacity_departure(
      @agency, name: "Deadline Departure", status: "draft"
    )
    @departure.update!(
      status: "active",
      departure_reference: "D-#{SecureRandom.random_number(900_000) + 100_000}",
      first_activated_at: Time.current,
      starts_on: Date.new(2027, 6, 15),
      ends_on: Date.new(2027, 6, 22),
      time_zone: "America/New_York"
    )
    @graph = create_capacity_graph(
      agency: @agency, departure: @departure,
      contractor: @supplier, provider: @supplier,
      prefix: "Deadline", capacity_management: "unmanaged"
    )
    @arrangement = @graph[:arrangement]
    @version = @graph[:version]
    create_ready_cost
    create_confirmation_trigger
  end

  test "draft deadline definition create update remove audits and freezes after activation" do
    result = CreateSupplierDeadlineDefinition.new(
      agency: @agency, actor: @actor, version: @version,
      attributes: informational_deadline_attrs(
        deadline_type: "rooming_list_due",
        rule_shape: "days_before_departure",
        rule_parameters: { "days" => 30 },
        precision: "date_only"
      ),
      version_lock_version: @version.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call
    definition = result.record
    assert_equal "rooming_list_due", definition.deadline_type
    assert_equal 30, definition.rule_parameters["days"]
    assert AuditEvent.exists?(action: "supplier_arrangement.deadline_definition_created")

    UpdateSupplierDeadlineDefinition.new(
      agency: @agency, actor: @actor, definition:,
      attributes: informational_deadline_attrs(
        deadline_type: "rooming_list_due",
        rule_shape: "days_before_departure",
        rule_parameters: { "days" => 21 },
        precision: "date_only",
        warning_lead_days: 3
      ),
      lock_version: definition.lock_version
    ).call
    assert_equal 21, definition.reload.rule_parameters["days"]
    assert_equal 3, definition.warning_lead_days

    activate_with_deadlines(elapsed_deadlines_acknowledged: false)
    assert_raises(AgencyCommand::Error) do
      UpdateSupplierDeadlineDefinition.new(
        agency: @agency, actor: @actor, definition: definition.reload,
        attributes: informational_deadline_attrs(
          deadline_type: "rooming_list_due",
          rule_shape: "days_before_departure",
          rule_parameters: { "days" => 14 },
          precision: "date_only"
        ),
        lock_version: definition.lock_version
      ).call
    end
    assert_raises(ActiveRecord::StatementInvalid) do
      definition.update_columns(description: "mutated", updated_at: Time.current)
    end
  end

  test "activation materializes occurrences projections and deadline_requirement openings exactly once" do
    informational = create_deadline!(
      kind: "informational",
      deadline_type: "final_count_due",
      rule_shape: "days_before_departure",
      rule_parameters: { "days" => 7 },
      precision: "date_only"
    )
    actionable = create_deadline!(
      kind: "actionable",
      deadline_type: "option_or_release_date",
      rule_shape: "fixed_date",
      rule_parameters: { "date" => "2027-05-01" },
      precision: "date_only",
      commitment_lines: [ {
        authority_shape: "fixed_quantity",
        description: "Hold eight cabins",
        committed_supplier_id: @supplier.id,
        fixed_quantity: 8,
        quantity_basis: "resource_units"
      } ]
    )

    activation = activate_with_deadlines.record
    occurrences = SupplierDeadlineOccurrence.where(supplier_arrangement_version: @version)
    assert_equal 2, occurrences.count
    assert_equal 1, occurrences.where(kind: "informational").count
    assert_equal 1, occurrences.where(kind: "actionable").count

    actionable_occurrence = occurrences.find_by!(supplier_deadline_definition: actionable)
    assert_equal Date.new(2027, 5, 1), actionable_occurrence.calculated_on
    assert_nil actionable_occurrence.calculated_at
    assert SupplierDeadlineProjection.exists?(supplier_deadline_occurrence: actionable_occurrence)

    deadline_commitments = SupplierCommitment.where(
      opening_kind: "deadline_requirement",
      supplier_deadline_occurrence: actionable_occurrence
    )
    assert_equal 1, deadline_commitments.count
    commitment = deadline_commitments.sole
    assert_nil commitment.supplier_confirmation_id
    assert_nil commitment.supplier_commitment_trigger_definition_id
    assert_equal 8, commitment.quantity
    assert_equal actionable.supplier_deadline_commitment_definition_lines.sole.id,
      commitment.supplier_deadline_commitment_definition_line_id

    assert_no_difference -> { SupplierDeadlineOccurrence.count } do
      assert_no_difference -> { SupplierCommitment.where(opening_kind: "deadline_requirement").count } do
        MaterializeSupplierDeadlineDefinitionsAlreadyLocked.new(
          agency: @agency, actor: @actor, arrangement: @arrangement,
          version: @version.reload, activation:, departure: @departure
        ).call
      end
    end

    assert AuditEvent.exists?(action: "supplier_arrangement.deadlines_materialized")
    assert_equal informational.id, occurrences.find_by!(kind: "informational").supplier_deadline_definition_id
  end

  test "projection refresh never opens commitments from elapsed time" do
    create_deadline!(
      kind: "actionable",
      deadline_type: "cancellation_cutoff",
      rule_shape: "fixed_date",
      rule_parameters: { "date" => (Date.current - 10).iso8601 },
      precision: "date_only",
      warning_lead_days: 2,
      commitment_lines: [ {
        authority_shape: "fixed_quantity",
        description: "Release held inventory",
        committed_supplier_id: @supplier.id,
        fixed_quantity: 2,
        quantity_basis: "resource_units"
      } ]
    )
    activation = activate_with_deadlines(elapsed_deadlines_acknowledged: true).record
    occurrence = SupplierDeadlineOccurrence.find_by!(
      supplier_arrangement_activation: activation, kind: "actionable"
    )
    before_count = SupplierCommitment.where(opening_kind: "deadline_requirement").count
    projection = RefreshSupplierDeadlineProjection.call(
      occurrence:, at: Time.current
    )
    assert_equal "overdue", projection.status
    assert_equal before_count, SupplierCommitment.where(opening_kind: "deadline_requirement").count

    RefreshDeadlineProjectionJob.perform_now(
      agency_id: @agency.id,
      supplier_deadline_occurrence_id: occurrence.id
    )
    assert_equal before_count, SupplierCommitment.where(opening_kind: "deadline_requirement").count
  end

  test "elapsed deadline activation requires explicit acknowledgment" do
    create_deadline!(
      kind: "informational",
      deadline_type: "legal_names_due",
      rule_shape: "fixed_date",
      rule_parameters: { "date" => (Date.current - 1).iso8601 },
      precision: "date_only"
    )
    error = assert_raises(AgencyCommand::Error) do
      activate_with_deadlines(elapsed_deadlines_acknowledged: false)
    end
    assert_equal :invalid, error.code
    assert_match(/elapsed/i, error.message)

    activation = activate_with_deadlines(elapsed_deadlines_acknowledged: true).record
    assert activation.elapsed_deadlines_acknowledged?
  end

  test "rule evaluator supports offsets composites and rejects milestone anchors" do
    days_before = create_deadline!(
      kind: "informational",
      deadline_type: "final_schedule_or_departure_time_due",
      rule_shape: "days_before_departure",
      rule_parameters: { "days" => 5 },
      precision: "date_only"
    )
    evaluated = SupplierDeadlineRuleEvaluator.call(definition: days_before, departure: @departure)
    assert_equal Date.new(2027, 6, 10), evaluated[:calculated_on]

    hours_before = create_deadline!(
      kind: "informational",
      deadline_type: "accessibility_confirmation_due",
      rule_shape: "hours_before_departure",
      rule_parameters: { "hours" => 48 },
      precision: "local_date_time",
      time_zone: "America/New_York"
    )
    evaluated = SupplierDeadlineRuleEvaluator.call(definition: hours_before, departure: @departure)
    assert_nil evaluated[:calculated_on]
    assert_equal Time.find_zone!("America/New_York").local(2027, 6, 13), evaluated[:calculated_at]

    earlier = create_deadline!(
      kind: "informational",
      deadline_type: "other",
      other_label: "Combined release",
      rule_shape: "earlier_of",
      precision: "date_only",
      rule_parameters: {
        "arms" => [
          { "rule_shape" => "fixed_date", "rule_parameters" => { "date" => "2027-04-01" } },
          { "rule_shape" => "days_before_departure", "rule_parameters" => { "days" => 10 } }
        ]
      }
    )
    evaluated = SupplierDeadlineRuleEvaluator.call(definition: earlier, departure: @departure)
    assert_equal Date.new(2027, 4, 1), evaluated[:calculated_on]

    error = assert_raises(AgencyCommand::Error) do
      CreateSupplierDeadlineDefinition.new(
        agency: @agency, actor: @actor, version: @version.reload,
        attributes: informational_deadline_attrs(
          deadline_type: "deposit_due",
          rule_shape: "fixed_date",
          rule_parameters: { "date" => "2027-01-01", "milestone" => "names_assigned_to_supplier" },
          precision: "date_only"
        ),
        version_lock_version: @version.lock_version,
        idempotency_key: SecureRandom.uuid
      ).call
    end
    assert_match(/milestone/i, error.message)
  end

  test "opening shape check separates confirmation_trigger and deadline_requirement" do
    create_deadline!(
      kind: "actionable",
      deadline_type: "option_or_release_date",
      rule_shape: "fixed_date",
      rule_parameters: { "date" => "2027-05-01" },
      precision: "date_only",
      commitment_lines: [ {
        authority_shape: "fixed_quantity",
        description: "Cabin hold",
        committed_supplier_id: @supplier.id,
        fixed_quantity: 3,
        quantity_basis: "resource_units"
      } ]
    )
    activation = activate_with_deadlines.record
    confirmation_commitment = activation.supplier_commitments.find_by!(opening_kind: "confirmation_trigger")
    deadline_commitment = activation.supplier_commitments.find_by!(opening_kind: "deadline_requirement")

    assert_raises(ActiveRecord::StatementInvalid) do
      ActiveRecord::Base.connection.execute(<<~SQL.squish)
        UPDATE supplier_commitments
        SET opening_kind = 'deadline_requirement',
            supplier_deadline_occurrence_id = '#{deadline_commitment.supplier_deadline_occurrence_id}',
            supplier_deadline_commitment_definition_line_id = '#{deadline_commitment.supplier_deadline_commitment_definition_line_id}'
        WHERE id = '#{confirmation_commitment.id}'
      SQL
    end
  end

  test "occurrence precision exclusivity is enforced" do
    create_deadline!(
      kind: "informational",
      deadline_type: "rooming_list_due",
      rule_shape: "fixed_date",
      rule_parameters: { "date" => "2027-05-01" },
      precision: "date_only"
    )
    activate_with_deadlines
    occurrence = SupplierDeadlineOccurrence.sole
    assert_raises(ActiveRecord::StatementInvalid) do
      ActiveRecord::Base.connection.execute(<<~SQL.squish)
        UPDATE supplier_deadline_occurrences
        SET calculated_at = NOW()
        WHERE id = '#{occurrence.id}'
      SQL
    end
  end

  test "successor activation transfers open deadline commitments without duplicates" do
    create_deadline!(
      kind: "actionable",
      deadline_type: "option_or_release_date",
      rule_shape: "fixed_date",
      rule_parameters: { "date" => "2027-05-01" },
      precision: "date_only",
      commitment_lines: [ {
        authority_shape: "fixed_quantity",
        description: "Hold eight cabins",
        committed_supplier_id: @supplier.id,
        fixed_quantity: 8,
        quantity_basis: "resource_units"
      } ]
    )
    activate_with_deadlines
    predecessor_commitment = SupplierCommitment.find_by!(opening_kind: "deadline_requirement")
    predecessor_occurrence = predecessor_commitment.supplier_deadline_occurrence

    successor = CreateSupplierArrangementSuccessor.new(
      agency: @agency, actor: @actor, arrangement: @arrangement.reload,
      arrangement_lock_version: @arrangement.lock_version,
      version_lock_version: @version.reload.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call.record
    assert successor.supplier_deadline_commitment_definition_lines.sole.copied_from_id.present?

    activate_successor(successor)
    open_deadline = SupplierCommitment.where(opening_kind: "deadline_requirement").select(&:open_state?)
    assert_equal 1, open_deadline.size
    assert_equal successor.id, open_deadline.sole.supplier_arrangement_version_id
    assert_equal "superseded", predecessor_commitment.reload.disposition_outcome
    assert_equal open_deadline.sole.id,
      predecessor_commitment.current_disposition.replacement_supplier_commitment_id
    assert predecessor_occurrence.reload.superseded_at.present?
    assert_equal "superseded", predecessor_occurrence.supplier_deadline_projection.reload.status
  end

  test "successor activation blocks when an open deadline definition is removed" do
    create_deadline!(
      kind: "actionable",
      deadline_type: "option_or_release_date",
      rule_shape: "fixed_date",
      rule_parameters: { "date" => "2027-05-01" },
      precision: "date_only",
      commitment_lines: [ {
        authority_shape: "fixed_quantity",
        description: "Hold inventory",
        committed_supplier_id: @supplier.id,
        fixed_quantity: 4,
        quantity_basis: "resource_units"
      } ]
    )
    activate_with_deadlines
    successor = CreateSupplierArrangementSuccessor.new(
      agency: @agency, actor: @actor, arrangement: @arrangement.reload,
      arrangement_lock_version: @arrangement.lock_version,
      version_lock_version: @version.reload.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call.record
    RemoveSupplierDeadlineDefinition.new(
      agency: @agency, actor: @actor,
      definition: successor.supplier_deadline_definitions.sole,
      version_lock_version: successor.lock_version
    ).call

    error = assert_raises(AgencyCommand::Error) { activate_successor(successor.reload) }
    assert_equal :invalid_state, error.code
    assert_match(/removed/i, error.message)
    assert_equal 1, SupplierCommitment.where(opening_kind: "deadline_requirement").select(&:open_state?).size
  end

  test "superseded occurrence projection leaves catch-up and shows superseded status" do
    create_deadline!(
      kind: "informational",
      deadline_type: "rooming_list_due",
      rule_shape: "fixed_date",
      rule_parameters: { "date" => (Date.current + 30).iso8601 },
      precision: "date_only",
      warning_lead_days: 5
    )
    activate_with_deadlines
    first_occurrence = SupplierDeadlineOccurrence.sole
    assert_equal "upcoming", first_occurrence.supplier_deadline_projection.status

    successor = CreateSupplierArrangementSuccessor.new(
      agency: @agency, actor: @actor, arrangement: @arrangement.reload,
      arrangement_lock_version: @arrangement.lock_version,
      version_lock_version: @version.reload.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call.record
    activate_successor(successor)

    first_occurrence.reload
    assert first_occurrence.superseded_at.present?
    assert_equal "superseded", first_occurrence.supplier_deadline_projection.reload.status
    assert_nil first_occurrence.supplier_deadline_projection.next_transition_at
    assert_not_includes RefreshDueDeadlineProjectionsJob.candidate_relation(at: Time.current).pluck(
      "supplier_deadline_projections.supplier_deadline_occurrence_id"
    ), first_occurrence.id
  end

  private

  def activate_successor(successor)
    ActivateSupplierArrangementVersion.new(
      agency: @agency, actor: @actor, arrangement: @arrangement.reload,
      version: successor,
      arrangement_lock_version: @arrangement.lock_version,
      version_lock_version: successor.lock_version,
      idempotency_key: SecureRandom.uuid,
      evidence_attributes: {
        evidence_kind: "supplier_confirmation", evidence_on: Date.current,
        channel: "portal", reference_note: "Successor evidence",
        confirmed_without_identifier_reason: "Supplier did not issue one"
      },
      cost_source_coverage_acknowledged: true,
      provisional_costs_acknowledged: true,
      commitment_trigger_coverage_acknowledged: true,
      elapsed_deadlines_acknowledged: true
    ).call
  end

  def informational_deadline_attrs(**overrides)
    {
      deadline_type: "rooming_list_due",
      kind: "informational",
      rule_shape: "fixed_date",
      rule_parameters: { "date" => "2027-05-01" },
      precision: "date_only",
      time_zone: "America/New_York",
      cardinality: "one_shared",
      coverage_links: [],
      commitment_lines: []
    }.merge(overrides)
  end

  def create_deadline!(**attrs)
    CreateSupplierDeadlineDefinition.new(
      agency: @agency, actor: @actor, version: @version.reload,
      attributes: informational_deadline_attrs(**attrs),
      version_lock_version: @version.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call.record
  end

  def activate_with_deadlines(**overrides)
    ActivateSupplierArrangementVersion.new(
      agency: @agency, actor: @actor, arrangement: @arrangement,
      version: @version.reload,
      arrangement_lock_version: @arrangement.reload.lock_version,
      version_lock_version: @version.lock_version,
      idempotency_key: SecureRandom.uuid,
      evidence_attributes: {
        evidence_kind: "supplier_confirmation", evidence_on: Date.current,
        channel: "portal", reference_note: "Supplier approved exact terms",
        confirmed_without_identifier_reason: "Supplier did not issue one"
      },
      cost_source_coverage_acknowledged: true,
      provisional_costs_acknowledged: true,
      commitment_trigger_coverage_acknowledged: true,
      elapsed_deadlines_acknowledged: false,
      **overrides
    ).call
  end

  def create_ready_cost
    source = SupplierCostSource.create!(
      agency: @agency, departure: @departure,
      supplier_arrangement: @arrangement,
      supplier_arrangement_version: @version,
      arrangement_item: @graph[:item],
      charging_supplier: @supplier,
      label: "Deadline lodging cost", position: 1
    )
    SupplierCostDefinition.create!(
      agency: @agency, departure: @departure,
      supplier_arrangement: @arrangement,
      supplier_arrangement_version: @version,
      supplier_cost_source: source,
      stage: "contracted", status: "forecast_ready", mode: "zero_cost",
      zero_cost_reason: "Included in package", currency: "USD",
      forecast_ready_by: @actor, forecast_ready_at: Time.current,
      readiness_fingerprint: "sha256:deadline",
      readiness_provenance: "Signed terms"
    )
  end

  def create_confirmation_trigger
    SupplierCommitmentTriggerDefinition.create!(
      agency: @agency, departure: @departure,
      supplier_arrangement: @arrangement,
      supplier_arrangement_version: @version,
      committed_supplier: @supplier,
      trigger_kind: "arrangement_confirmation",
      authority_shape: "fixed_quantity",
      description: "Ten guaranteed rooms",
      fixed_quantity: 10, quantity_basis: "resource_units", position: 1
    )
  end
end
