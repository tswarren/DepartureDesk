# frozen_string_literal: true

require "test_helper"

class CruiseSupplierDepositAdapterTest < ActiveSupport::TestCase
  include CapacityGraphHelper

  setup do
    @agency = agencies(:harbor)
    @staff = agency_users(:harbor_staff)
    @contractor = create_capacity_supplier(@agency, "Celebrity Cruises")
    @departure = create_capacity_departure(@agency, name: "Smith Family Cruise")
    @setup = create_cruise_with_two_cabin_pools
    @arrangement = @setup[:arrangement]
    @version = @arrangement.versions.sole
    @item = @arrangement.arrangement_items.sole
    @pools = @setup[:pools]
  end

  test "preview candidate matches subsequently saved evaluator inputs" do
    form = {
      template: "initial_deposit",
      description: "Initial deposit",
      amount_shape: "quantity_times_rate",
      quantity_basis: "capacity_pool_units",
      rate_amount: "50",
      rule_shape: "fixed_date",
      fixed_date: "2026-09-20",
      capacity_pool_ids: @pools.map(&:id)
    }
    candidate = CruiseDepositCandidateNormalizer.call(
      template_key: "initial_deposit",
      form: form,
      arrangement: @arrangement,
      version: @version,
      cruise_item: @item,
      currency: "USD"
    )

    assert_no_difference -> { AuditEvent.count } do
      assert_no_difference -> { @version.supplier_deposit_requirement_definitions.count } do
        preview = PreviewCruiseDepositRequirement.call(
          agency: @agency,
          arrangement: @arrangement,
          version: @version,
          candidate: candidate,
          version_lock_version: @version.lock_version
        )
        assert_equal "ready", preview.status
        assert_equal 120_000, preview.amount_minor_units
        assert_equal 24, preview.inputs["quantity"]
        @preview_inputs = preview.inputs
      end
    end

    result = CreateSupplierDepositRequirementDefinition.new(
      agency: @agency,
      actor: @staff,
      version: @version,
      attributes: candidate.attributes,
      version_lock_version: @version.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call
    definition = result.record
    saved = SupplierDepositAmountEvaluator.call(
      definition: definition,
      version: @version.reload,
      arrangement: @arrangement,
      mode: :preview
    )
    assert_equal @preview_inputs["quantity"], saved[:inputs]["quantity"]
    assert_equal @preview_inputs["rate_minor_units"], saved[:inputs]["rate_minor_units"]
    assert_equal(
      @preview_inputs["sources"].map { |row| row["capacity_pool_id"] }.sort,
      saved[:inputs]["sources"].map { |row| row["capacity_pool_id"] }.sort
    )
  end

  test "draft cumulative uses provisional openings and draft contributor credits" do
    initial = create_initial!(rate: 5_000)
    form = {
      template: "final_deposit",
      description: "Final deposit",
      amount_shape: "cumulative_target",
      quantity_basis: "capacity_pool_units",
      rate_amount: "500",
      rule_shape: "earlier_of",
      arm1_rule_shape: "planning_milestone",
      arm1_milestone_kind: "names_assigned_to_supplier",
      arm2_rule_shape: "fixed_date",
      arm2_fixed_date: "2027-03-11",
      capacity_pool_ids: @pools.map(&:id),
      contributor_definition_ids: [ initial.id ]
    }
    candidate = CruiseDepositCandidateNormalizer.call(
      template_key: "final_deposit",
      form: form,
      arrangement: @arrangement,
      version: @version,
      cruise_item: @item,
      currency: "USD"
    )
    preview = PreviewCruiseDepositRequirement.call(
      agency: @agency,
      arrangement: @arrangement,
      version: @version,
      candidate: candidate
    )
    assert_equal "ready", preview.status
    assert_equal "provisional_retained", preview.inputs["quantity_phase"]
    assert_equal "If activated with the current cabin block", preview.quantity_label
    # 24 cabins × $500 = 1_200_000; initial credit 24 × $50 = 120_000; remaining 1_080_000
    assert_equal 1_080_000, preview.amount_minor_units
    sources = preview.inputs["sources"]
    assert_equal 2, sources.size
    assert sources.all? { |row| row["credited_minor_units"].positive? }
  end

  test "detector rejects unsupported quantity basis and projects typed initial" do
    initial = create_initial!(rate: 5_000)
    detected = DetectCruiseDepositRequirementShape.new(
      agency: @agency,
      arrangement: @arrangement,
      definition: initial,
      version: @version
    ).call
    assert detected.compatible?
    assert_equal "initial_deposit", detected.template

    initial.update_columns(quantity_basis: "traveler_positions")
    advanced = DetectCruiseDepositRequirementShape.new(
      agency: @agency,
      arrangement: @arrangement,
      definition: initial.reload,
      version: @version
    ).call
    refute advanced.compatible?
    assert advanced.reasons.any? { |reason| reason.match?(/traveler/i) }
  end

  test "workspace compiles deposit rows instead of placeholder" do
    create_initial!(rate: 5_000)
    workspace = CompileCruiseDepositsAndDeadlinesWorkspace.new(
      agency: @agency,
      arrangement: @arrangement,
      version: @version
    ).call
    assert workspace.compatible?
    assert_equal 1, workspace.deposit_rows.size
    assert_equal "edit", workspace.deposit_rows.first.action
    refute_respond_to workspace, :deposit_placeholder
  end

  test "deposit update replaces coverage without nulling ownership foreign keys" do
    initial = create_initial!(rate: 5_000)
    first_pool = @pools.first
    second_pool = @pools.last
    assert_operator @pools.size, :>=, 2

    before_ids = initial.supplier_deposit_requirement_definition_coverage_links.order(:id).pluck(:id)
    assert_operator before_ids.size, :>=, 1

    candidate = CruiseDepositCandidateNormalizer.call(
      template_key: "initial_deposit",
      form: {
        template: "initial_deposit",
        description: initial.description,
        amount_shape: "quantity_times_rate",
        quantity_basis: "capacity_pool_units",
        rate_amount: "75",
        rule_shape: "fixed_date",
        fixed_date: "2026-09-20",
        capacity_pool_ids: [ second_pool.id ]
      },
      arrangement: @arrangement,
      version: @version,
      cruise_item: @item,
      currency: "USD",
      cumulative_definition: initial
    )

    UpdateSupplierDepositRequirementDefinition.new(
      agency: @agency,
      actor: @staff,
      definition: initial,
      attributes: candidate.attributes,
      lock_version: initial.lock_version
    ).call

    initial.reload
    links = initial.supplier_deposit_requirement_definition_coverage_links.order(:position, :id)
    assert_equal 1, links.size
    assert_equal second_pool.id, links.first.capacity_pool_id
    assert_equal initial.id, links.first.supplier_deposit_requirement_definition_id
    assert_equal @agency.id, links.first.agency_id
    assert_equal 7_500, initial.rate_minor_units
    # In-place update may retain the row id; ownership keys must never null.
    assert links.first.supplier_deposit_requirement_definition_id.present?
  end

  test "final deposit coverage update keeps contributor links without readonly errors" do
    initial = create_initial!(rate: 5_000)
    final = CreateSupplierDepositRequirementDefinition.new(
      agency: @agency,
      actor: @staff,
      version: @version.reload,
      attributes: {
        amount_shape: "cumulative_target",
        currency: "USD",
        rate_minor_units: 50_000,
        quantity_basis: "capacity_pool_units",
        rule_shape: "fixed_date",
        rule_parameters: { "date" => "2027-03-11" },
        precision: "date_only",
        time_zone: "America/New_York",
        description: "Final deposit",
        coverage_links: @pools.map { |pool|
          definition = @version.capacity_pool_definitions.find_by!(capacity_pool_id: pool.id)
          {
            capacity_pool_id: pool.id,
            arrangement_item_id: definition.arrangement_item_id,
            service_occurrence_id: definition.service_occurrence_id,
            supplier_resource_id: definition.supplier_resource_id
          }
        },
        contributor_definition_ids: [ initial.id ]
      },
      version_lock_version: @version.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call.record

    assert_equal 1, final.supplier_deposit_requirement_definition_contributor_links.count
    contributor_link_id = final.supplier_deposit_requirement_definition_contributor_links.sole.id
    second_pool = @pools.last

    candidate = CruiseDepositCandidateNormalizer.call(
      template_key: "final_deposit",
      form: {
        template: "final_deposit",
        description: final.description,
        amount_shape: "cumulative_target",
        quantity_basis: "capacity_pool_units",
        rate_amount: "500",
        rule_shape: "fixed_date",
        fixed_date: "2027-03-11",
        capacity_pool_ids: [ second_pool.id ],
        contributor_definition_ids: [ initial.id ]
      },
      arrangement: @arrangement,
      version: @version,
      cruise_item: @item,
      currency: "USD",
      cumulative_definition: final
    )

    UpdateSupplierDepositRequirementDefinition.new(
      agency: @agency,
      actor: @staff,
      definition: final,
      attributes: candidate.attributes,
      lock_version: final.lock_version
    ).call

    final.reload
    links = final.supplier_deposit_requirement_definition_coverage_links.order(:position, :id)
    assert_equal 1, links.size
    assert_equal second_pool.id, links.first.capacity_pool_id
    contributors = final.supplier_deposit_requirement_definition_contributor_links.order(:position, :id)
    assert_equal 1, contributors.size
    assert_equal initial.id, contributors.sole.contributor_definition_id
    assert_equal contributor_link_id, contributors.sole.id
    assert_equal final.id, contributors.sole.supplier_deposit_requirement_definition_id
  end

  test "preview and save share validation for negative rates and incompatible contributors" do
    initial = create_initial!(rate: 5_000)
    other_pool_only = @pools.last

    error = assert_raises(AgencyCommand::Error) do
      CruiseDepositCandidateNormalizer.call(
        template_key: "initial_deposit",
        form: {
          template: "initial_deposit",
          description: "Bad rate",
          amount_shape: "quantity_times_rate",
          quantity_basis: "capacity_pool_units",
          rate_amount: "-50",
          rule_shape: "fixed_date",
          fixed_date: "2026-09-20",
          capacity_pool_ids: [ @pools.first.id ]
        },
        arrangement: @arrangement,
        version: @version,
        cruise_item: @item,
        currency: "USD"
      )
    end
    assert_match(/non-negative|valid/i, error.message)

    # Contributor covering an unrelated pool only.
    isolated = CreateSupplierDepositRequirementDefinition.new(
      agency: @agency,
      actor: @staff,
      version: @version,
      attributes: {
        amount_shape: "quantity_times_rate",
        currency: "USD",
        rate_minor_units: 1_000,
        quantity_basis: "capacity_pool_units",
        rule_shape: "fixed_date",
        rule_parameters: { "date" => "2026-09-21" },
        precision: "date_only",
        time_zone: "America/New_York",
        description: "Isolated pool deposit",
        coverage_links: [ {
          capacity_pool_id: other_pool_only.id,
          arrangement_item_id: @version.capacity_pool_definitions
            .find_by!(capacity_pool_id: other_pool_only.id).arrangement_item_id,
          service_occurrence_id: @version.capacity_pool_definitions
            .find_by!(capacity_pool_id: other_pool_only.id).service_occurrence_id,
          supplier_resource_id: @version.capacity_pool_definitions
            .find_by!(capacity_pool_id: other_pool_only.id).supplier_resource_id
        } ]
      },
      version_lock_version: @version.reload.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call.record

    error = assert_raises(AgencyCommand::Error) do
      CruiseDepositCandidateNormalizer.call(
        template_key: "final_deposit",
        form: {
          template: "final_deposit",
          description: "Final deposit",
          amount_shape: "cumulative_target",
          quantity_basis: "capacity_pool_units",
          rate_amount: "500",
          rule_shape: "fixed_date",
          fixed_date: "2027-03-11",
          capacity_pool_ids: [ @pools.first.id ],
          contributor_definition_ids: [ isolated.id ]
        },
        arrangement: @arrangement,
        version: @version,
        cruise_item: @item,
        currency: "USD"
      )
    end
    assert_match(/cover at least one capacity pool/i, error.message)

    final = CreateSupplierDepositRequirementDefinition.new(
      agency: @agency,
      actor: @staff,
      version: @version,
      attributes: {
        amount_shape: "cumulative_target",
        currency: "USD",
        rate_minor_units: 50_000,
        quantity_basis: "capacity_pool_units",
        rule_shape: "fixed_date",
        rule_parameters: { "date" => "2027-03-11" },
        precision: "date_only",
        time_zone: "America/New_York",
        description: "Final deposit",
        coverage_links: pool_coverage(@pools.first),
        contributor_definition_ids: [ initial.id ]
      },
      version_lock_version: @version.reload.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call.record

    later = CreateSupplierDepositRequirementDefinition.new(
      agency: @agency,
      actor: @staff,
      version: @version,
      attributes: {
        amount_shape: "quantity_times_rate",
        currency: "USD",
        rate_minor_units: 2_000,
        quantity_basis: "capacity_pool_units",
        rule_shape: "fixed_date",
        rule_parameters: { "date" => "2026-09-22" },
        precision: "date_only",
        time_zone: "America/New_York",
        description: "Later deposit",
        coverage_links: pool_coverage(@pools.first)
      },
      version_lock_version: @version.reload.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call.record

    error = assert_raises(AgencyCommand::Error) do
      CruiseDepositCandidateNormalizer.call(
        template_key: "final_deposit",
        form: {
          template: "final_deposit",
          description: "Final deposit",
          amount_shape: "cumulative_target",
          quantity_basis: "capacity_pool_units",
          rate_amount: "500",
          rule_shape: "fixed_date",
          fixed_date: "2027-03-11",
          capacity_pool_ids: [ @pools.first.id ],
          contributor_definition_ids: [ later.id ]
        },
        arrangement: @arrangement,
        version: @version,
        cruise_item: @item,
        currency: "USD",
        cumulative_definition: final
      )
    end
    assert_match(/earlier deposit/i, error.message)
  end

  test "typed fixed deposits accept independent resource coverage" do
    resource_id = @version.supplier_resource_definitions.order(:position, :id).first.supplier_resource_id
    candidate = CruiseDepositCandidateNormalizer.call(
      template_key: "other_deposit",
      form: {
        template: "other_deposit",
        description: "Fixed cabin deposit",
        amount_shape: "fixed_amount",
        fixed_amount: "100",
        coverage_scope: "resource",
        supplier_resource_ids: [ resource_id ],
        rule_shape: "fixed_date",
        fixed_date: "2026-09-20"
      },
      arrangement: @arrangement,
      version: @version,
      cruise_item: @item,
      currency: "USD"
    )
    assert_equal 1, candidate.coverage_links.size
    assert_equal resource_id, candidate.coverage_links.first[:supplier_resource_id]

    result = CreateSupplierDepositRequirementDefinition.new(
      agency: @agency,
      actor: @staff,
      version: @version,
      attributes: candidate.attributes,
      version_lock_version: @version.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call
    detected = DetectCruiseDepositRequirementShape.new(
      agency: @agency,
      arrangement: @arrangement,
      definition: result.record,
      version: @version
    ).call
    assert detected.compatible?
  end

  private

  def pool_coverage(pool)
    definition = @version.capacity_pool_definitions.find_by!(capacity_pool_id: pool.id)
    [ {
      capacity_pool_id: pool.id,
      arrangement_item_id: definition.arrangement_item_id,
      service_occurrence_id: definition.service_occurrence_id,
      supplier_resource_id: definition.supplier_resource_id
    } ]
  end

  def create_initial!(rate:)
    CreateSupplierDepositRequirementDefinition.new(
      agency: @agency,
      actor: @staff,
      version: @version,
      attributes: {
        amount_shape: "quantity_times_rate",
        currency: "USD",
        rate_minor_units: rate,
        quantity_basis: "capacity_pool_units",
        rule_shape: "fixed_date",
        rule_parameters: { "date" => "2026-09-20" },
        precision: "date_only",
        time_zone: "America/New_York",
        description: "Initial deposit",
        coverage_links: @pools.map { |pool|
          definition = @version.capacity_pool_definitions.find_by!(capacity_pool_id: pool.id)
          {
            capacity_pool_id: pool.id,
            arrangement_item_id: definition.arrangement_item_id,
            service_occurrence_id: definition.service_occurrence_id,
            supplier_resource_id: definition.supplier_resource_id
          }
        }
      },
      version_lock_version: @version.reload.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call.record
  end

  def create_cruise_with_two_cabin_pools
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
    pools = []
    [
      [ "Prime Oceanview", "O1", 8 ],
      [ "Veranda", "V1", 16 ]
    ].each do |name, code, qty|
      cabin = CreateCruiseCabinCategorySetup.new(
        agency: @agency,
        actor: @staff,
        arrangement: arrangement,
        resource_attributes: {
          name: name,
          supplier_code: code,
          maximum_occupancy: 3
        },
        pool_attributes: {
          inventory_mode: "block",
          proposed_opening_quantity: qty,
          evidence_kind: "contract",
          evidence_on: Date.current,
          evidence_reference_note: "Signed cabin block"
        },
        version_lock_version: version.reload.lock_version,
        idempotency_key: SecureRandom.uuid
      ).call
      pools << cabin.record.pool
    end
    { arrangement: arrangement, pools: pools }
  end
end
