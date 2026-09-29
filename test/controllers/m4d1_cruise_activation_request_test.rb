# frozen_string_literal: true

require "test_helper"

class M4d1CruiseActivationRequestTest < ActionDispatch::IntegrationTest
  include CapacityGraphHelper
  include CruiseActivationGateHelper

  setup do
    @agency = agencies(:harbor)
    @staff = agency_users(:harbor_staff)
    @contractor = create_capacity_supplier(@agency, "Celebrity Cruises")
    @departure = create_capacity_departure(@agency, name: "Smith Family Cruise")
    @departure.update!(
      status: "active",
      departure_reference: "D-#{SecureRandom.random_number(900_000) + 100_000}",
      first_activated_at: Time.current
    )
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
      item_attributes: { name: "Celebrity Beyond", default_service_provider_id: provider.id },
      occurrence_attributes: {
        name: "Western Caribbean",
        starts_on: "2027-11-06",
        ends_on: "2027-11-13",
        time_zone: "America/New_York"
      },
      idempotency_key: SecureRandom.uuid
    ).call
    @arrangement = sailing.record.arrangement
    @version = @arrangement.versions.sole
    cabin = CreateCruiseCabinCategorySetup.new(
      agency: @agency,
      actor: @staff,
      arrangement: @arrangement,
      resource_attributes: { name: "Prime Oceanview", supplier_code: "O1", maximum_occupancy: 3 },
      pool_attributes: {
        inventory_mode: "block",
        proposed_opening_quantity: 8,
        evidence_kind: "contract",
        evidence_on: Date.current,
        evidence_reference_note: "Signed cabin block"
      },
      version_lock_version: @version.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call
    @pool = cabin.record.pool
    satisfy_cruise_activation_gate!(
      agency: @agency, actor: @staff, arrangement: @arrangement, version: @version.reload
    )
  end

  test "a post-eligible cruise activates through the existing command without acknowledging an estimate" do
    sign_in_as @staff
    get departure_arrangement_cruise_activation_path(@departure, @arrangement)
    assert_response :success
    assert_match "This Cruise can be activated from this review.", response.body
    assert_match "No confirmation-triggered commitments are declared.", response.body
    assert_match "Group reference 1119999", response.body
    assert_select "input#confirmation_display_value[value='1119999']", count: 0
    assert_no_match "provisional_costs_acknowledged", response.body
    assert_no_match "I confirm the entered cost-source list is complete.", response.body

    captured = []
    assert_difference "SupplierConfirmation.count", 1 do
      with_constructor_capture(ActivateSupplierArrangementVersion, captured) do
        post departure_arrangement_cruise_activation_path(@departure, @arrangement), params: activation_params
      end
    end
    assert_equal true, captured.sole[:cost_source_coverage_acknowledged]
    assert_equal true, captured.sole[:commitment_trigger_coverage_acknowledged]
    assert_equal false, captured.sole[:provisional_costs_acknowledged]
    assert_redirected_to departure_arrangement_cruise_activation_path(@departure, @arrangement)
    assert @version.reload.activated?
    follow_redirect!
    assert_match "Connect to Client service", response.body
    assert_match "Version #{@version.version_number} is now the governing", response.body
  end

  test "cruise agreement confirmation is not reused as supplier confirmation" do
    sign_in_as @staff
    assert_no_difference "SupplierConfirmation.count" do
      post departure_arrangement_cruise_activation_path(@departure, @arrangement), params: activation_params(
        confirmation: { evidence_kind: "", evidence_on: "", channel: "", reference_note: "" }
      )
    end
    assert_response :unprocessable_entity
    assert @version.reload.draft?
  end

  test "an estimate selection has no cruise post" do
    version = @version.reload
    source = SupplierCostSource.create!(
      agency: @agency, departure: @departure, supplier_arrangement: @arrangement,
      supplier_arrangement_version: version, arrangement_item: @arrangement.arrangement_items.sole,
      charging_supplier: @contractor, label: "Planning estimate",
      position: version.supplier_cost_sources.maximum(:position).to_i + 1
    )
    source.supplier_cost_definitions.create!(
      agency: @agency, departure: @departure, supplier_arrangement: @arrangement,
      supplier_arrangement_version: version, stage: "estimate", status: "forecast_ready",
      mode: "zero_cost", zero_cost_reason: "Planning only", currency: "USD",
      forecast_ready_by: @staff, forecast_ready_at: Time.current,
      readiness_fingerprint: "sha256:estimate", readiness_provenance: "Planning"
    )
    sign_in_as @staff
    get departure_arrangement_cruise_activation_path(@departure, @arrangement)
    assert_no_match "Activate Cruise supplier arrangement", response.body
    assert_match "Advanced Supplier planning", response.body

    post departure_arrangement_cruise_activation_path(@departure, @arrangement), params: activation_params
    assert_response :unprocessable_entity
    assert @version.reload.draft?
  end

  test "a requirement that becomes elapsed between review and post is not activated" do
    sign_in_as @staff
    get departure_arrangement_cruise_activation_path(@departure, @arrangement)
    assert_no_match "already past due", response.body

    CreateSupplierDeadlineDefinition.new(
      agency: @agency,
      actor: @staff,
      version: @version.reload,
      attributes: {
        deadline_type: "option_or_release_date",
        kind: "actionable",
        rule_shape: "fixed_date",
        rule_parameters: { "date" => "2020-01-01" },
        precision: "date_only",
        time_zone: "America/New_York",
        cardinality: "one_shared",
        coverage_links: [ { arrangement_item_id: @arrangement.arrangement_items.sole.id } ],
        commitment_lines: [
          {
            authority_shape: "fixed_quantity",
            description: "Retain or release cabins",
            committed_supplier_id: @contractor.id,
            fixed_quantity: 8,
            quantity_basis: "resource_units"
          }
        ]
      },
      version_lock_version: @version.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call

    post departure_arrangement_cruise_activation_path(@departure, @arrangement), params: activation_params
    assert_response :unprocessable_entity
    assert_match "elapsed after this review was opened", response.body
    assert @version.reload.draft?
  end

  test "elapsed acknowledgment is submitted only from the checkbox" do
    create_elapsed_deadline!
    sign_in_as @staff
    review = CompileCruiseActivationReview.new(
      agency: @agency, arrangement: @arrangement, version: @version.reload
    ).call
    assert review.elapsed.any?

    post departure_arrangement_cruise_activation_path(@departure, @arrangement), params: activation_params(
      elapsed_definition_ids: review.elapsed.map(&:definition_id)
    )
    assert_response :unprocessable_entity
    assert_match "already-elapsed", response.body
    assert @version.reload.draft?

    post departure_arrangement_cruise_activation_path(@departure, @arrangement), params: activation_params(
      elapsed_definition_ids: review.elapsed.map(&:definition_id),
      elapsed_deadlines_acknowledged: "1"
    )
    assert_redirected_to departure_arrangement_cruise_activation_path(@departure, @arrangement)
    assert @version.reload.activated?
  end

  test "a stale lock does not activate" do
    sign_in_as @staff
    post departure_arrangement_cruise_activation_path(@departure, @arrangement), params: activation_params(
      version_lock_version: @version.lock_version - 1
    )
    assert_response :unprocessable_entity
    assert @version.reload.draft?
  end

  test "duplicate identifier review does not activate" do
    sign_in_as @staff
    command = Object.new
    command.define_singleton_method(:call) do
      raise AgencyCommand::DuplicateReviewRequired.new(
        token: "review-token",
        candidates: [ OpenStruct.new(signals: [ "supplier_issued_identifier", "1119999" ]) ]
      )
    end
    with_constructor(ActivateSupplierArrangementVersion, command) do
      post departure_arrangement_cruise_activation_path(@departure, @arrangement), params: activation_params
    end
    assert_response :unprocessable_entity
    assert_match "Matching Supplier identifiers", response.body
    assert @version.reload.draft?
  end

  private

  def with_constructor(klass, replacement)
    singleton = klass.singleton_class
    singleton.alias_method :new_without_activation_stub, :new
    singleton.define_method(:new) { |**| replacement }
    yield
  ensure
    singleton.alias_method :new, :new_without_activation_stub
    singleton.remove_method :new_without_activation_stub
  end

  def with_constructor_capture(klass, captured)
    singleton = klass.singleton_class
    singleton.alias_method :new_without_activation_capture, :new
    singleton.define_method(:new) do |**kwargs|
      captured << kwargs
      new_without_activation_capture(**kwargs)
    end
    yield
  ensure
    singleton.alias_method :new, :new_without_activation_capture
    singleton.remove_method :new_without_activation_capture
  end

  def create_elapsed_deadline!
    CreateSupplierDeadlineDefinition.new(
      agency: @agency,
      actor: @staff,
      version: @version.reload,
      attributes: {
        deadline_type: "option_or_release_date",
        kind: "actionable",
        rule_shape: "fixed_date",
        rule_parameters: { "date" => "2020-01-01" },
        precision: "date_only",
        time_zone: "America/New_York",
        cardinality: "one_shared",
        coverage_links: [ { arrangement_item_id: @arrangement.arrangement_items.sole.id } ],
        commitment_lines: [
          {
            authority_shape: "fixed_quantity",
            description: "Retain or release cabins",
            committed_supplier_id: @contractor.id,
            fixed_quantity: 8,
            quantity_basis: "resource_units"
          }
        ]
      },
      version_lock_version: @version.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call
  end

  def activation_params(overrides = {})
    {
      idempotency_key: SecureRandom.uuid,
      arrangement_lock_version: @arrangement.reload.lock_version,
      version_lock_version: @version.reload.lock_version,
      confirmation: {
        evidence_kind: "supplier_confirmation",
        evidence_on: Date.current.to_s,
        channel: "portal",
        reference_note: "Supplier approved the terms",
        confirmed_without_identifier_reason: "Supplier did not issue one"
      }
    }.deep_merge(overrides)
  end
end
