# frozen_string_literal: true

require "test_helper"

class M4d1CruiseSupplierDeadlinesRequestTest < ActionDispatch::IntegrationTest
  include CapacityGraphHelper

  setup do
    @agency = agencies(:harbor)
    @staff = agency_users(:harbor_staff)
    @viewer = agency_users(:harbor_viewer)
    @contractor = create_capacity_supplier(@agency, "Celebrity Cruises")
    @departure = create_capacity_departure(@agency, name: "Smith Family Cruise")
    @setup = create_cruise_with_cabin
    @arrangement = @setup[:arrangement]
    @resource = @setup[:resource]
    @version = @arrangement.versions.sole
    @item = @arrangement.arrangement_items.sole
  end

  test "workspace links from cruise show and creates typed deadlines" do
    sign_in_as @staff

    get departure_arrangement_cruise_path(@departure, @arrangement)
    assert_response :success
    assert_select "a", text: "Open deposits and deadlines"

    get departure_arrangement_cruise_deposits_and_deadlines_path(@departure, @arrangement)
    assert_response :success
    assert_select "#cruise-deposits-and-deadlines"
    assert_select "a", text: "Add Supplier deadline"
    assert_select "a", text: "Add deposit requirement"
    assert_select "a", text: "Open advanced Deadlines"
    assert_match(/return_to=#{CompileCruiseDepositsAndDeadlinesWorkspace::RETURN_TOKEN}/, response.body)

    get departure_arrangement_cruise_deposits_and_deadlines_path(
      @departure, @arrangement, editor: "new"
    )
    assert_response :success
    assert_select "#cruise-deadline-editor"
    assert_select "select[name='cruise_deadline[template]']"
    assert_select "p.dd-help", text: /Planning-milestone timing is not available/
    assert_select "select[name='cruise_deadline[rule_shape]'] option", text: /milestone/, count: 0

    assert_difference -> { @version.supplier_deadline_definitions.count }, 1 do
      post departure_arrangement_cruise_deposits_and_deadlines_deadlines_path(
        @departure, @arrangement
      ), params: {
        version_lock_version: @version.lock_version,
        idempotency_key: SecureRandom.uuid,
        cruise_deadline: {
          template: "option_or_release",
          kind: "actionable",
          rule_shape: "fixed_date",
          fixed_date: "2027-03-11",
          coverage_scope: "arrangement",
          description: "Review retained cabins and release any unretained block by the option date",
          warning_lead_days: "7"
        }
      }
    end
    assert_response :redirect
    assert_match %r{/cruise/deposits-and-deadlines\?focus_deadline_id=}, @response.redirect_url

    definition = @version.supplier_deadline_definitions.order(:position, :id).last
    assert_equal "option_or_release_date", definition.deadline_type
    assert_equal "actionable", definition.kind
    assert_equal 1, definition.supplier_deadline_definition_coverage_links.count
    assert_equal @item.id, definition.supplier_deadline_definition_coverage_links.sole.arrangement_item_id
    line = definition.supplier_deadline_commitment_definition_lines.sole
    assert_equal 1, line.fixed_quantity
    assert_equal "resource_units", line.quantity_basis
    assert_equal @contractor.id, line.committed_supplier_id

    follow_redirect!
    assert_response :success
    assert_match(/Option or release date|Option\/release/i, response.body)
  end

  test "invalid second deadline leaves first unchanged and redisplays fields" do
    sign_in_as @staff
    first = create_typed_deadline_via_command!("option_or_release", "2027-03-11")

    assert_no_difference -> { @version.supplier_deadline_definitions.count } do
      post departure_arrangement_cruise_deposits_and_deadlines_deadlines_path(
        @departure, @arrangement
      ), params: {
        version_lock_version: @version.reload.lock_version,
        idempotency_key: SecureRandom.uuid,
        cruise_deadline: {
          template: "other",
          kind: "informational",
          other_label: "Broken sibling",
          rule_shape: "days_before_departure",
          offset_days: "0",
          coverage_scope: "arrangement"
        }
      }
    end

    assert_response :unprocessable_entity
    assert_select "#form-error-summary[data-controller='form-error-summary']"
    assert_select "input[name='cruise_deadline[offset_days]'][value=?]", "0"
    assert_equal first.id, @version.supplier_deadline_definitions.sole.id
    assert_equal "actionable", first.reload.kind
  end

  test "viewer cannot mutate and cross-agency is not found" do
    sign_in_as @viewer
    post departure_arrangement_cruise_deposits_and_deadlines_deadlines_path(
      @departure, @arrangement
    ), params: {
      version_lock_version: @version.lock_version,
      idempotency_key: SecureRandom.uuid,
      cruise_deadline: {
        template: "rooming_list",
        kind: "informational",
        rule_shape: "fixed_date",
        fixed_date: "2027-10-07",
        coverage_scope: "arrangement"
      }
    }
    assert_redirected_to root_path
    assert_equal 0, @version.supplier_deadline_definitions.count

    sign_in_as @staff
    other = agencies(:cove)
    foreign_departure = create_capacity_departure(other, name: "Foreign Cruise")
    foreign_supplier = create_capacity_supplier(other, "Foreign Line")
    foreign = CreateCruiseSailingSetup.new(
      agency: other,
      actor: agency_users(:cove_admin),
      departure: foreign_departure,
      arrangement_attributes: {
        name: "Foreign agreement",
        contracting_supplier_id: foreign_supplier.id
      },
      item_attributes: { name: "Foreign ship" },
      occurrence_attributes: {
        name: "Foreign sailing",
        starts_on: "2027-11-06",
        ends_on: "2027-11-13",
        time_zone: "America/New_York"
      },
      idempotency_key: SecureRandom.uuid
    ).call
    get departure_arrangement_cruise_deposits_and_deadlines_path(
      foreign_departure, foreign.record.arrangement
    )
    assert_response :not_found
  end

  test "active governing version is read-only and successor owns mutations" do
    sign_in_as @staff
    governing = create_typed_deadline_via_command!("option_or_release", "2027-03-11")
    activate_cruise!(@arrangement, @version.reload, @setup[:resource])

    get departure_arrangement_cruise_deposits_and_deadlines_path(@departure, @arrangement)
    assert_response :success
    assert_match(/read-only/i, response.body)
    assert_select "a", text: "Add Supplier deadline", count: 0
    assert_select "a", text: "Edit", count: 0

    post departure_arrangement_cruise_deposits_and_deadlines_deadlines_path(
      @departure, @arrangement
    ), params: {
      version_lock_version: @version.reload.lock_version,
      idempotency_key: SecureRandom.uuid,
      cruise_deadline: {
        template: "rooming_list",
        kind: "informational",
        rule_shape: "fixed_date",
        fixed_date: "2027-10-07",
        coverage_scope: "arrangement"
      }
    }
    assert_redirected_to departure_arrangement_cruise_deposits_and_deadlines_path(
      @departure, @arrangement
    )
    follow_redirect!
    assert_match(/successor draft/i, response.body)

    successor = CreateSupplierArrangementSuccessor.new(
      agency: @agency,
      actor: @staff,
      arrangement: @arrangement.reload,
      arrangement_lock_version: @arrangement.lock_version,
      version_lock_version: @version.reload.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call.record

    get departure_arrangement_cruise_deposits_and_deadlines_path(@departure, @arrangement)
    assert_response :success
    assert_select "a", text: "Add Supplier deadline"

    patch departure_arrangement_cruise_deposits_and_deadlines_deadline_path(
      @departure, @arrangement, governing
    ), params: {
      lock_version: governing.lock_version,
      cruise_deadline: {
        template: "option_or_release",
        kind: "actionable",
        rule_shape: "fixed_date",
        fixed_date: "2027-04-01",
        coverage_scope: "arrangement",
        description: "Should not mutate governing"
      }
    }
    assert_response :not_found
    assert_equal "2027-03-11", governing.reload.rule_parameters["date"]

    copied = successor.supplier_deadline_definitions.find_by(copied_from_id: governing.id) ||
      successor.supplier_deadline_definitions.find_by(deadline_type: "option_or_release_date")
    assert copied

    patch departure_arrangement_cruise_deposits_and_deadlines_deadline_path(
      @departure, @arrangement, copied
    ), params: {
      lock_version: copied.lock_version,
      cruise_deadline: {
        template: "option_or_release",
        kind: "actionable",
        rule_shape: "fixed_date",
        fixed_date: "2027-04-01",
        coverage_scope: "arrangement",
        description: copied.supplier_deadline_commitment_definition_lines.sole.description
      }
    }
    assert_response :redirect
    assert_match %r{/cruise/deposits-and-deadlines\?focus_deadline_id=#{copied.id}}, @response.redirect_url
    assert_equal "2027-04-01", copied.reload.rule_parameters["date"]
  end

  private

  def create_typed_deadline_via_command!(template_key, date)
    attrs = CruiseDeadlineTemplateSupport.compile_attributes(
      template_key: template_key,
      kind: nil,
      other_label: nil,
      description: nil,
      warning_lead_days: nil,
      timing: { rule_shape: "fixed_date", fixed_date: date },
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

  def activate_cruise!(arrangement, version, resource)
    @departure.update!(
      status: "active",
      departure_reference: "D-#{SecureRandom.random_number(900_000) + 100_000}",
      first_activated_at: Time.current
    )
    resource_definition = version.supplier_resource_definitions.find_by!(supplier_resource: resource)
    source = SupplierCostSource.create!(
      agency: @agency,
      departure: @departure,
      supplier_arrangement: arrangement,
      supplier_arrangement_version: version,
      arrangement_item: arrangement.arrangement_items.sole,
      charging_supplier: @contractor,
      label: "Entered cruise cost",
      position: 1
    )
    SupplierCostDefinition.create!(
      agency: @agency,
      departure: @departure,
      supplier_arrangement: arrangement,
      supplier_arrangement_version: version,
      supplier_cost_source: source,
      stage: "contracted",
      status: "forecast_ready",
      mode: "zero_cost",
      zero_cost_reason: "Included in package",
      currency: "USD",
      forecast_ready_by: @staff,
      forecast_ready_at: Time.current,
      readiness_fingerprint: "sha256:cruise-deadline-activate",
      readiness_provenance: "Signed terms"
    )
    SupplierCommitmentTriggerDefinition.create!(
      agency: @agency,
      departure: @departure,
      supplier_arrangement: arrangement,
      supplier_arrangement_version: version,
      committed_supplier: @contractor,
      trigger_kind: "arrangement_confirmation",
      authority_shape: "fixed_quantity",
      description: "Eight guaranteed cabins",
      fixed_quantity: 8,
      quantity_basis: "resource_units",
      position: 1
    )

    ActivateSupplierArrangementVersion.new(
      agency: @agency,
      actor: @staff,
      arrangement: arrangement,
      version: version,
      arrangement_lock_version: arrangement.reload.lock_version,
      version_lock_version: version.reload.lock_version,
      idempotency_key: SecureRandom.uuid,
      evidence_attributes: {
        evidence_kind: "supplier_confirmation",
        evidence_on: Date.current,
        channel: "portal",
        reference_note: "Supplier approved exact terms",
        confirmed_without_identifier_reason: "Supplier did not issue one"
      },
      cost_source_coverage_acknowledged: true,
      provisional_costs_acknowledged: true,
      commitment_trigger_coverage_acknowledged: true,
      elapsed_deadlines_acknowledged: true
    ).call
    resource_definition
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
        proposed_opening_quantity: 8,
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
