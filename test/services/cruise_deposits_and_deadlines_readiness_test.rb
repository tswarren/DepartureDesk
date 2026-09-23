# frozen_string_literal: true

require "test_helper"

class CruiseDepositsAndDeadlinesReadinessTest < ActiveSupport::TestCase
  include CapacityGraphHelper

  setup do
    @agency = agencies(:harbor)
    @staff = agency_users(:harbor_staff)
    @contractor = create_capacity_supplier(@agency, "Celebrity Cruises")
    @departure = create_capacity_departure(@agency, name: "Smith Family Cruise")
    @setup = create_cruise_with_cabin(opening_quantity: 8)
    @arrangement = @setup[:arrangement]
    @version = @arrangement.versions.sole
    @pool = @version.capacity_pool_definitions.sole.capacity_pool
    @item = @arrangement.arrangement_items.sole
    @resource = @setup[:resource]
  end

  test "draft readiness is ready with structured deposit and deadline fields" do
    create_typed_deadline!
    create_typed_deposit!

    workspace = CompileCruiseDepositsAndDeadlinesWorkspace.new(
      agency: @agency,
      arrangement: @arrangement,
      version: @version
    ).call

    readiness = workspace.readiness
    assert_equal :ready, readiness.state
    assert_equal "Ready for activation review", readiness.heading
    assert_equal 1, readiness.deposit_count
    assert_equal 1, readiness.deadline_count
    assert_equal 2, readiness.actionable_commitment_count
    assert_empty readiness.unique_blockers
    assert readiness.can_activate?
    assert_includes readiness.activation_path, "/activation"
    assert_match(/1 deposit requirement/i, readiness.summary_sentence)

    deposit = workspace.deposit_rows.sole
    assert_equal "Initial", deposit.semantic_type_label
    assert_match(/per initially blocked cabin/i, deposit.amount_label)
    assert_equal deposit.timing_sentence, deposit.due_label
    assert_equal deposit.coverage_summary, deposit.coverage_label
    assert_equal "Ready", deposit.status_label
    assert deposit.amount_sentence.present?

    deadline = workspace.deadline_rows.sole
    assert deadline.compatible?, -> { deadline.shape.reasons.join("; ") }
    assert_equal "Action required", deadline.semantic_type_label
    assert_nil deadline.amount_label
    assert_equal deadline.timing_sentence, deadline.due_label
    assert_equal "Ready", deadline.status_label
  end

  test "activation blockers are unique and cabin quantity maps to cabin inventory" do
    create_typed_deposit!
    clear_opening_quantity!

    preview = PreviewCruiseDepositsAndDeadlinesActivation.call(
      agency: @agency,
      arrangement: @arrangement,
      version: @version.reload,
      version_lock_version: @version.lock_version
    )

    assert_equal "blocked", preview.status
    assert_operator preview.blockers.size, :>=, 1
    assert_equal preview.blockers.map { |message| normalize(message) }.uniq.size,
      preview.unique_blockers.size

    cabin_blocker = preview.unique_blockers.find { |blocker|
      blocker.message.match?(/opening quantity|capacity.?pool quantity/i)
    }
    assert cabin_blocker, "expected a cabin-quantity blocker"
    assert_match(%r{/cruise/cabin-categories/}, cabin_blocker.corrective_path)
    assert_equal "Open cabin inventory", cabin_blocker.corrective_label
    assert_equal "#cruise-deposit-#{cabin_blocker.definition_id}", cabin_blocker.editor_anchor

    workspace = CompileCruiseDepositsAndDeadlinesWorkspace.new(
      agency: @agency,
      arrangement: @arrangement,
      version: @version,
      activation_preview: preview
    ).call

    readiness = workspace.readiness
    assert_equal :blocked, readiness.state
    assert_equal "Not ready to activate", readiness.heading
    refute readiness.can_activate?
    assert_equal 1, readiness.unique_blockers.size
    assert_equal cabin_blocker.message, readiness.unique_blockers.first.message
    assert_equal cabin_blocker.corrective_path, readiness.unique_blockers.first.corrective_path
    assert_equal "Blocked", workspace.deposit_rows.sole.status_label
    row_blocker = workspace.deposit_rows.sole.row_blocker
    assert row_blocker, "expected per-row blocker facts"
    assert_equal cabin_blocker.message, row_blocker.message
    assert_equal cabin_blocker.corrective_path, row_blocker.corrective_path
    assert_equal "Open cabin inventory", row_blocker.corrective_label
  end

  test "display label prefers detector template when description is a generated default" do
    assert_equal "Final deposit",
      CruiseDepositsAndDeadlinesLanguage.deposit_display_label(
        description: "Initial deposit",
        template: "final_deposit"
      )
    assert_equal "Initial deposit",
      CruiseDepositsAndDeadlinesLanguage.deposit_display_label(
        description: "Final deposit",
        template: "initial_deposit"
      )
    assert_equal "Custom group hold",
      CruiseDepositsAndDeadlinesLanguage.deposit_display_label(
        description: "Custom group hold",
        template: "final_deposit"
      )

    initial = create_typed_deposit!(description: "Initial deposit")
    CreateSupplierDepositRequirementDefinition.new(
      agency: @agency,
      actor: @staff,
      version: @version.reload,
      attributes: {
        description: "Final deposit",
        amount_shape: "cumulative_target",
        quantity_basis: "capacity_pool_units",
        rate_minor_units: 50_000,
        currency: "USD",
        rule_shape: "fixed_date",
        rule_parameters: { "date" => "2027-03-11" },
        precision: "date_only",
        time_zone: "America/New_York",
        coverage_links: pool_coverage(@pool),
        contributor_definition_ids: [ initial.id ]
      },
      version_lock_version: @version.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call
    final = @version.reload.supplier_deposit_requirement_definitions.order(:id).last
    final.update_columns(description: "Initial deposit", updated_at: Time.current)

    workspace = CompileCruiseDepositsAndDeadlinesWorkspace.new(
      agency: @agency,
      arrangement: @arrangement,
      version: @version
    ).call

    final_row = workspace.deposit_rows.find { |row| row.definition.id == final.id }
    assert final_row
    assert_equal "final_deposit", final_row.template.to_s
    assert_equal "Final deposit", final_row.display_label
    assert_equal "Final", final_row.semantic_type_label
    assert_equal "Initial deposit", final.reload.description
  end

  test "governing display retains persisted description despite detector template" do
    initial = create_typed_deposit!(description: "Initial deposit")
    CreateSupplierDepositRequirementDefinition.new(
      agency: @agency,
      actor: @staff,
      version: @version.reload,
      attributes: {
        description: "Final deposit",
        amount_shape: "cumulative_target",
        quantity_basis: "capacity_pool_units",
        rate_minor_units: 50_000,
        currency: "USD",
        rule_shape: "fixed_date",
        rule_parameters: { "date" => "2027-03-11" },
        precision: "date_only",
        time_zone: "America/New_York",
        coverage_links: pool_coverage(@pool),
        contributor_definition_ids: [ initial.id ]
      },
      version_lock_version: @version.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call
    final = @version.reload.supplier_deposit_requirement_definitions.order(:id).last
    final.update_columns(description: "Initial deposit", updated_at: Time.current)
    @version.update_columns(
      status: "activated",
      activated_at: Time.current,
      updated_at: Time.current
    )

    workspace = CompileCruiseDepositsAndDeadlinesWorkspace.new(
      agency: @agency,
      arrangement: @arrangement,
      version: @version.reload
    ).call

    refute workspace.editable?
    assert workspace.governing_read_only?
    final_row = workspace.deposit_rows.find { |row| row.definition.id == final.id }
    assert final_row
    assert_equal "final_deposit", final_row.template.to_s
    assert_equal "Initial deposit", final_row.display_label
    assert_equal "Initial deposit", final.reload.description
  end

  test "per-row blockers keep definition-specific cabin corrective links" do
    second = CreateCruiseCabinCategorySetup.new(
      agency: @agency,
      actor: @staff,
      arrangement: @arrangement,
      resource_attributes: {
        name: "Veranda",
        supplier_code: "V1",
        maximum_occupancy: 3
      },
      pool_attributes: {
        inventory_mode: "block",
        proposed_opening_quantity: 4,
        evidence_kind: "contract",
        evidence_on: Date.current,
        evidence_reference_note: "Second cabin block"
      },
      version_lock_version: @version.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call
    second_resource = second.record.resource
    second_pool = @version.reload.capacity_pool_definitions
      .find { |row| row.supplier_resource_id == second_resource.id }
      .capacity_pool

    first_deposit = create_typed_deposit!(description: "Oceanview deposit", date: "2026-09-20")
    # Retarget first deposit coverage to the first pool only (already true).
    second_deposit = CreateSupplierDepositRequirementDefinition.new(
      agency: @agency,
      actor: @staff,
      version: @version.reload,
      attributes: {
        description: "Veranda deposit",
        amount_shape: "quantity_times_rate",
        quantity_basis: "capacity_pool_units",
        rate_minor_units: 6_000,
        currency: "USD",
        rule_shape: "fixed_date",
        rule_parameters: { "date" => "2026-09-21" },
        precision: "date_only",
        time_zone: "America/New_York",
        coverage_links: pool_coverage(second_pool)
      },
      version_lock_version: @version.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call.record

    @version.capacity_pool_definitions.find_each do |pool_definition|
      pool_definition.update_columns(proposed_opening_quantity: nil, updated_at: Time.current)
    end

    preview = PreviewCruiseDepositsAndDeadlinesActivation.call(
      agency: @agency,
      arrangement: @arrangement,
      version: @version.reload,
      version_lock_version: @version.lock_version
    )
    first_preview = preview.rows.find { |row| row.definition_id == first_deposit.id }
    second_preview = preview.rows.find { |row| row.definition_id == second_deposit.id }
    assert first_preview.blocker.present?
    assert second_preview.blocker.present?
    assert_equal normalize(first_preview.blocker), normalize(second_preview.blocker)
    assert_match(%r{/cabin-categories/#{@resource.id}/edit}, first_preview.corrective_path)
    assert_match(%r{/cabin-categories/#{second_resource.id}/edit}, second_preview.corrective_path)
    refute_equal first_preview.corrective_path, second_preview.corrective_path

    workspace = CompileCruiseDepositsAndDeadlinesWorkspace.new(
      agency: @agency,
      arrangement: @arrangement,
      version: @version,
      activation_preview: preview
    ).call

    first_row = workspace.deposit_rows.find { |row| row.definition.id == first_deposit.id }
    second_row = workspace.deposit_rows.find { |row| row.definition.id == second_deposit.id }
    assert_equal first_preview.corrective_path, first_row.row_blocker.corrective_path
    assert_equal second_preview.corrective_path, second_row.row_blocker.corrective_path
  end

  test "duplicate blocker messages collapse to one unique blocker" do
    first = create_typed_deposit!(description: "Initial deposit A", date: "2026-09-20")
    second = create_typed_deposit!(description: "Initial deposit B", date: "2026-09-21")
    clear_opening_quantity!

    preview = PreviewCruiseDepositsAndDeadlinesActivation.call(
      agency: @agency,
      arrangement: @arrangement,
      version: @version.reload,
      version_lock_version: @version.lock_version
    )

    deposit_blockers = preview.rows.select { |row|
      row.kind == "deposit" && row.blocker.present?
    }
    assert_equal 2, deposit_blockers.size
    assert_equal normalize(deposit_blockers.first.blocker),
      normalize(deposit_blockers.second.blocker)
    assert_equal 1, preview.unique_blockers.size
    assert_includes [ first.id, second.id ], preview.unique_blockers.first.definition_id
  end

  test "definition blockers point at deposits and deadlines editor query params" do
    create_typed_deposit!
    definition = @version.supplier_deposit_requirement_definitions.sole
    SupplierDepositRequirementDefinitionCoverageLink
      .where(supplier_deposit_requirement_definition_id: definition.id)
      .delete_all

    preview = PreviewCruiseDepositsAndDeadlinesActivation.call(
      agency: @agency,
      arrangement: @arrangement,
      version: @version.reload,
      version_lock_version: @version.lock_version
    )

    assert_equal "blocked", preview.status
    blocker = preview.unique_blockers.find { |row| row.kind == "deposit" }
    assert blocker
    assert_match(/coverage/i, blocker.message)
    refute_match(%r{/cruise/cabin-categories/}, blocker.corrective_path)
    assert_includes blocker.corrective_path, "deposit_editor=edit"
    assert_includes blocker.corrective_path, "deposit_id=#{definition.id}"
    assert_equal "Edit deposit requirement", blocker.corrective_label
  end

  test "amount shape labels use Staff-facing business language" do
    assert_equal "Fixed amount",
      CruiseDepositsAndDeadlinesLanguage.amount_shape_label("fixed_amount")
    assert_equal "Amount per initially blocked cabin",
      CruiseDepositsAndDeadlinesLanguage.amount_shape_label(
        "quantity_times_rate", quantity_basis: "capacity_pool_units"
      )
    assert_equal "Amount per explicit quantity",
      CruiseDepositsAndDeadlinesLanguage.amount_shape_label(
        "quantity_times_rate", quantity_basis: "explicit"
      )
    assert_equal "Cumulative amount per retained cabin",
      CruiseDepositsAndDeadlinesLanguage.amount_shape_label(
        "cumulative_target", quantity_basis: "capacity_pool_units"
      )
  end

  test "incompatible cruise shape returns nil readiness" do
    lodging = create_capacity_graph(
      agency: @agency,
      departure: @departure,
      contractor: @contractor,
      provider: create_capacity_supplier(@agency, "Bus Ops"),
      prefix: "Lodging"
    )
    workspace = CompileCruiseDepositsAndDeadlinesWorkspace.new(
      agency: @agency,
      arrangement: lodging[:arrangement]
    ).call

    refute workspace.compatible?
    assert_nil workspace.readiness
  end

  private

  def normalize(message)
    message.to_s.strip.downcase.gsub(/\s+/, " ")
  end

  def clear_opening_quantity!
    @version.capacity_pool_definitions.update_all(proposed_opening_quantity: nil)
  end

  def create_typed_deadline!
    attrs = CruiseDeadlineTemplateSupport.compile_attributes(
      template_key: "option_or_release",
      kind: nil,
      other_label: nil,
      description: nil,
      warning_lead_days: nil,
      timing: { rule_shape: "fixed_date", fixed_date: "2027-02-01" },
      coverage: { scope: "arrangement" },
      arrangement: @arrangement,
      version: @version.reload,
      cruise_item: @item
    )
    CreateSupplierDeadlineDefinition.new(
      agency: @agency,
      actor: @staff,
      version: @version,
      attributes: attrs,
      version_lock_version: @version.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call
    @version.reload
  end

  def create_typed_deposit!(description: "Initial deposit", date: "2026-09-20")
    result = CreateSupplierDepositRequirementDefinition.new(
      agency: @agency,
      actor: @staff,
      version: @version,
      attributes: {
        description: description,
        amount_shape: "quantity_times_rate",
        quantity_basis: "capacity_pool_units",
        rate_minor_units: 5_000,
        currency: "USD",
        rule_shape: "fixed_date",
        rule_parameters: { "date" => date },
        precision: "date_only",
        time_zone: "America/New_York",
        coverage_links: pool_coverage(@pool)
      },
      version_lock_version: @version.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call
    @version.reload
    result.record
  end

  def pool_coverage(pool)
    definition = @version.capacity_pool_definitions.find_by!(capacity_pool_id: pool.id)
    [ {
      capacity_pool_id: pool.id,
      arrangement_item_id: definition.arrangement_item_id,
      service_occurrence_id: definition.service_occurrence_id,
      supplier_resource_id: definition.supplier_resource_id
    } ]
  end

  def create_cruise_with_cabin(opening_quantity:)
    provider = create_capacity_supplier(@agency, "Celebrity Ship Ops")
    contact = @contractor.contacts.create!(
      agency: @agency, first_name: "Group", last_name: "Desk", status: "active"
    )
    sailing = CreateCruiseSailingSetup.new(
      agency: @agency,
      actor: @staff,
      departure: @departure,
      arrangement_attributes: {
        name: "Celebrity group agreement",
        contracting_supplier_id: @contractor.id,
        supplier_contact_id: contact.id
      },
      item_attributes: {
        name: "Celebrity Beyond",
        default_service_provider_id: provider.id
      },
      occurrence_attributes: {
        name: "Western Caribbean",
        starts_on: "2027-11-06",
        ends_on: "2027-11-13",
        time_zone: "America/New_York"
      },
      idempotency_key: SecureRandom.uuid
    ).call
    arrangement = sailing.record.arrangement
    version = arrangement.versions.sole
    cabin = CreateCruiseCabinCategorySetup.new(
      agency: @agency,
      actor: @staff,
      arrangement: arrangement,
      resource_attributes: {
        name: "Prime Oceanview",
        supplier_code: "O1",
        maximum_occupancy: 3
      },
      pool_attributes: {
        inventory_mode: "block",
        proposed_opening_quantity: opening_quantity,
        evidence_kind: "contract",
        evidence_on: Date.current,
        evidence_reference_note: "Signed cabin block"
      },
      version_lock_version: version.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call
    { arrangement: arrangement, resource: cabin.record.resource }
  end
end
