# frozen_string_literal: true

require "test_helper"

class CruiseSupplierDeadlineAdapterTest < ActiveSupport::TestCase
  include CapacityGraphHelper

  setup do
    @agency = agencies(:harbor)
    @staff = agency_users(:harbor_staff)
    @contractor = create_capacity_supplier(@agency, "Celebrity Cruises")
    @departure = create_capacity_departure(@agency, name: "Smith Family Cruise")
    @setup = create_cruise_with_cabin
    @arrangement = @setup[:arrangement]
    @version = @arrangement.versions.sole
    @item = @arrangement.arrangement_items.sole
    @resource = @setup[:resource]
  end

  test "compile attributes create exact coverage and typed commitment line" do
    attrs = CruiseDeadlineTemplateSupport.compile_attributes(
      template_key: "option_or_release",
      kind: "informational",
      other_label: nil,
      description: nil,
      warning_lead_days: 7,
      timing: { rule_shape: "fixed_date", fixed_date: "2027-03-11" },
      coverage: { scope: "arrangement" },
      arrangement: @arrangement,
      version: @version,
      cruise_item: @item
    )

    assert_equal "option_or_release_date", attrs[:deadline_type]
    assert_equal "actionable", attrs[:kind]
    assert_equal @item.id, attrs[:coverage_links].first[:arrangement_item_id] ||
      attrs[:coverage_links].first["arrangement_item_id"]
    assert_equal 1, attrs[:commitment_lines].size
    line = attrs[:commitment_lines].first
    assert_equal "fixed_quantity", line[:authority_shape]
    assert_equal 1, line[:fixed_quantity]
    assert_equal "resource_units", line[:quantity_basis]
    assert_equal @contractor.id, line[:committed_supplier_id]
  end

  test "create update and remove preserve child graphs and independence" do
    first = create_typed_deadline!(
      template_key: "option_or_release",
      timing: { rule_shape: "fixed_date", fixed_date: "2027-03-11" }
    )
    coverage_id = first.supplier_deadline_definition_coverage_links.sole.id
    line_id = first.supplier_deadline_commitment_definition_lines.sole.id

    UpdateSupplierDeadlineDefinition.new(
      agency: @agency,
      actor: @staff,
      definition: first,
      attributes: CruiseDeadlineTemplateSupport.compile_attributes(
        template_key: "option_or_release",
        kind: "actionable",
        other_label: nil,
        description: first.supplier_deadline_commitment_definition_lines.sole.description,
        warning_lead_days: 14,
        timing: { rule_shape: "fixed_date", fixed_date: "2027-03-11" },
        coverage: { scope: "arrangement" },
        arrangement: @arrangement,
        version: @version.reload,
        cruise_item: @item
      ),
      lock_version: first.lock_version
    ).call

    first.reload
    assert_equal 14, first.warning_lead_days
    assert_equal coverage_id, first.supplier_deadline_definition_coverage_links.sole.id
    assert_equal line_id, first.supplier_deadline_commitment_definition_lines.sole.id

    UpdateSupplierDeadlineDefinition.new(
      agency: @agency,
      actor: @staff,
      definition: first,
      attributes: CruiseDeadlineTemplateSupport.compile_attributes(
        template_key: "final_payment",
        kind: "informational",
        other_label: "Final payment",
        description: "Evidence only",
        warning_lead_days: nil,
        timing: { rule_shape: "fixed_date", fixed_date: "2027-07-09" },
        coverage: { scope: "arrangement" },
        arrangement: @arrangement,
        version: @version.reload,
        cruise_item: @item
      ),
      lock_version: first.lock_version
    ).call

    first.reload
    assert_equal "informational", first.kind
    assert_equal "Final payment", first.other_label
    assert_empty first.supplier_deadline_commitment_definition_lines
    assert_equal 1, first.supplier_deadline_definition_coverage_links.count

    previous_coverage = first.supplier_deadline_definition_coverage_links.sole.attributes
    assert_raises(AgencyCommand::Error) do
      UpdateSupplierDeadlineDefinition.new(
        agency: @agency,
        actor: @staff,
        definition: first,
        attributes: CruiseDeadlineTemplateSupport.compile_attributes(
          template_key: "final_payment",
          kind: "actionable",
          other_label: "Final payment",
          description: "Retry",
          warning_lead_days: nil,
          timing: { rule_shape: "fixed_date", fixed_date: "not-a-date" },
          coverage: { scope: "arrangement" },
          arrangement: @arrangement,
          version: @version.reload,
          cruise_item: @item
        ),
        lock_version: first.lock_version
      ).call
    end
    first.reload
    assert_equal "informational", first.kind
    assert_equal previous_coverage["id"], first.supplier_deadline_definition_coverage_links.sole.id
    assert_empty first.supplier_deadline_commitment_definition_lines

    second = create_typed_deadline!(
      template_key: "rooming_list",
      timing: { rule_shape: "fixed_date", fixed_date: "2027-10-07" }
    )
    assert_equal "informational", second.kind
    assert_empty second.supplier_deadline_commitment_definition_lines

    RemoveSupplierDeadlineDefinition.new(
      agency: @agency,
      actor: @staff,
      definition: second,
      version_lock_version: @version.reload.lock_version
    ).call

    assert_not SupplierDeadlineDefinition.exists?(second.id)
    assert SupplierDeadlineDefinition.exists?(first.id)
    assert_equal 0, SupplierDeadlineOccurrence.where(supplier_deadline_definition_id: second.id).count
  end

  test "detector rejects unsupported topology without writes" do
    definition = CreateSupplierDeadlineDefinition.new(
      agency: @agency, actor: @staff, version: @version,
      attributes: {
        deadline_type: "option_or_release_date",
        kind: "actionable",
        rule_shape: "fixed_date",
        rule_parameters: { "date" => "2027-03-11" },
        precision: "date_only",
        time_zone: "America/New_York",
        cardinality: "one_shared",
        coverage_links: [ { arrangement_item_id: @item.id } ],
        commitment_lines: [ {
          authority_shape: "fixed_quantity",
          description: "Hold four cabins",
          committed_supplier_id: @contractor.id,
          fixed_quantity: 4,
          quantity_basis: "resource_units"
        } ]
      },
      version_lock_version: @version.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call.record

    before = fingerprint(definition)
    shape = DetectCruiseSupplierDeadlineShape.new(
      agency: @agency, arrangement: @arrangement, definition: definition, version: @version
    ).call
    assert_not shape.compatible?
    assert_match(/commitment line must match/i, shape.reasons.join(" "))
    assert_equal before, fingerprint(definition.reload)

    mismatched = create_typed_deadline!(
      template_key: "option_or_release",
      timing: { rule_shape: "fixed_date", fixed_date: "2027-04-01" },
      description: "Supplier contract deadline"
    )
    line = mismatched.supplier_deadline_commitment_definition_lines.sole
    line.update_columns(description: "Retain or release eight cabins")
    shape = DetectCruiseSupplierDeadlineShape.new(
      agency: @agency, arrangement: @arrangement, definition: mismatched.reload, version: @version
    ).call
    assert_not shape.compatible?
    assert_match(/action\/evidence text/i, shape.reasons.join(" "))

    milestone_blob = definition.rule_parameters.merge(
      "arms" => [ {
        "rule_shape" => "planning_milestone",
        "rule_parameters" => { "kind" => "names_assigned_to_supplier" }
      } ]
    )
    definition.update_columns(rule_shape: "earlier_of", rule_parameters: milestone_blob, precision: "date_only")
    shape = DetectCruiseSupplierDeadlineShape.new(
      agency: @agency, arrangement: @arrangement, definition: definition, version: @version.reload
    ).call
    assert_not shape.compatible?
    assert shape.reasons.any? { |reason| reason.match?(/milestone/i) }
  end

  test "typed reopen unchanged save preserves complete child graph" do
    definition = create_typed_deadline!(
      template_key: "option_or_release",
      timing: { rule_shape: "fixed_date", fixed_date: "2027-03-11" },
      description: "Review retained cabins and release any unretained block by the option date"
    )
    before = fingerprint(definition)
    shape = DetectCruiseSupplierDeadlineShape.new(
      agency: @agency, arrangement: @arrangement, definition: definition, version: @version
    ).call
    assert shape.compatible?
    fields = shape.projected_fields.with_indifferent_access

    UpdateSupplierDeadlineDefinition.new(
      agency: @agency,
      actor: @staff,
      definition: definition,
      attributes: CruiseDeadlineTemplateSupport.compile_attributes(
        template_key: fields[:template],
        kind: fields[:kind],
        other_label: fields[:other_label],
        description: fields[:description],
        warning_lead_days: fields[:warning_lead_days],
        timing: fields[:timing],
        coverage: {
          scope: fields.dig(:coverage, :scope),
          supplier_resource_id: fields.dig(:coverage, :supplier_resource_id),
          capacity_pool_id: fields.dig(:coverage, :capacity_pool_id)
        },
        arrangement: @arrangement,
        version: @version.reload,
        cruise_item: @item
      ),
      lock_version: definition.lock_version
    ).call

    reopened = DetectCruiseSupplierDeadlineShape.new(
      agency: @agency, arrangement: @arrangement, definition: definition.reload, version: @version
    ).call
    assert reopened.compatible?
    after = fingerprint(definition)
    assert_equal before[0].except("lock_version"), after[0].except("lock_version")
    assert_equal before[1].map { |row| row.except("id", "lock_version", "updated_at", "created_at") },
      after[1].map { |row| row.except("id", "lock_version", "updated_at", "created_at") }
    assert_equal before[2].map { |row| row.except("id", "lock_version", "updated_at", "created_at") },
      after[2].map { |row| row.except("id", "lock_version", "updated_at", "created_at") }
  end

  test "workspace compilation is write-free and definition-scoped" do
    typed = create_typed_deadline!(
      template_key: "option_or_release",
      timing: { rule_shape: "fixed_date", fixed_date: "2027-03-11" }
    )
    advanced = CreateSupplierDeadlineDefinition.new(
      agency: @agency, actor: @staff, version: @version.reload,
      attributes: {
        deadline_type: "cancellation_cutoff",
        kind: "informational",
        rule_shape: "fixed_date",
        rule_parameters: { "date" => "2027-01-01" },
        precision: "date_only",
        time_zone: "America/New_York",
        cardinality: "one_shared",
        coverage_links: [ { arrangement_item_id: @item.id } ],
        commitment_lines: []
      },
      version_lock_version: @version.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call.record

    before = [ fingerprint(typed), fingerprint(advanced) ]
    workspace = CompileCruiseDepositsAndDeadlinesWorkspace.new(
      agency: @agency, arrangement: @arrangement
    ).call

    assert workspace.compatible?
    assert workspace.editable?
    assert_equal 2, workspace.deadline_rows.size
    typed_row = workspace.deadline_rows.find { |row| row.definition.id == typed.id }
    advanced_row = workspace.deadline_rows.find { |row| row.definition.id == advanced.id }
    assert typed_row.compatible?
    assert_not advanced_row.compatible?
    assert_includes workspace.advanced_deadlines_path, "return_to=#{CompileCruiseDepositsAndDeadlinesWorkspace::RETURN_TOKEN}"
    assert_equal before, [ fingerprint(typed.reload), fingerprint(advanced.reload) ]
  end

  test "duplicate coverage is rejected at adapter boundary" do
    error = assert_raises(AgencyCommand::Error) do
      CruiseDeadlineTemplateSupport.normalize_coverage_links!([
        { arrangement_item_id: @item.id },
        { arrangement_item_id: @item.id }
      ])
    end
    assert_match(/unique/i, error.message)
  end

  private

  def create_typed_deadline!(template_key:, timing:, kind: nil, other_label: nil, description: nil)
    attrs = CruiseDeadlineTemplateSupport.compile_attributes(
      template_key: template_key,
      kind: kind,
      other_label: other_label,
      description: description,
      warning_lead_days: nil,
      timing: timing,
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
    ).call.record
  end

  def fingerprint(definition)
    [
      definition.attributes.slice(
        "deadline_type", "other_label", "kind", "rule_shape", "rule_parameters",
        "precision", "warning_lead_days", "description", "lock_version"
      ),
      definition.supplier_deadline_definition_coverage_links.order(:position, :id).map(&:attributes),
      definition.supplier_deadline_commitment_definition_lines.order(:position, :id).map(&:attributes)
    ]
  end

  def create_cruise_with_cabin
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
        proposed_opening_quantity: 8
      },
      version_lock_version: version.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call
    { arrangement: arrangement, resource: cabin.record.resource }
  end
end
