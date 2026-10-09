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

  test "an identical activation post replays after the group is activated" do
    sign_in_as @staff
    params = activation_params
    assert_difference -> { SupplierConfirmation.count }, 1 do
      post departure_arrangement_cruise_activation_path(@departure, @arrangement), params: params
    end
    assert_redirected_to departure_arrangement_cruise_activation_path(@departure, @arrangement)

    assert_no_difference [ "SupplierConfirmation.count", "SupplierArrangementActivation.count", "AuditEvent.count" ] do
      post departure_arrangement_cruise_activation_path(@departure, @arrangement), params: params
    end
    assert_redirected_to departure_arrangement_cruise_activation_path(@departure, @arrangement)
    follow_redirect!
    assert_match "already activated", response.body
  end

  test "a post-eligible cruise activates through the existing command without acknowledging an estimate" do
    sign_in_as @staff
    get departure_arrangement_cruise_activation_path(@departure, @arrangement)
    assert_response :success
    assert_select "h1", text: "Review & activate"
    assert_select "#cruise-activation-status", text: "Ready to review"
    assert_select "#cruise-activation-inventory th", text: "Opening quantity"
    assert_select ".dd-table-wrap #cruise-activation-inventory"
    assert_select ".dd-table-wrap #cruise-activation-rates"
    assert_match "No confirmation-triggered commitments will open.", response.body
    assert_match "No confirmation-triggered commitments are declared.", response.body
    assert_select "input#supplier_reference[value='1119999']"
    assert_select "table"
    assert_match "Contracted terms", response.body
    assert_select "input[type=submit][value=?]", "Confirm and activate group"
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
    assert_select "h1", text: "View activation review"
    assert_select "#cruise-activation-status", text: "Active"
    assert_select "#cruise-activated-heading"
    assert_select "dl.dd-fact-grid"
    assert_match "Version #{@version.version_number} became governing", response.body
    assert_match "Activated by Sam Carter", response.body
    assert_no_match "Supplier-issued identifier", response.body
    assert_no_match "Confirm and activate group", response.body
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
    review = CompileCruiseActivationReview.new(
      agency: @agency, arrangement: @arrangement, version: @version.reload
    ).call
    assert_equal true, review.readiness_ready?
    assert_equal false, review.cruise_post_allowed?
    assert_empty review.blockers
    assert_select "#cruise-activation-status", text: "Requires Advanced"
    assert_match "The Supplier setup is ready", response.body
    assert_match "cannot safely represent the activation", response.body
    assert_no_match "Confirm and activate group", response.body
    assert_select "a[href=?]", departure_arrangement_activation_path(@departure, @arrangement), text: "Open Advanced Supplier planning"

    post departure_arrangement_cruise_activation_path(@departure, @arrangement), params: activation_params
    assert_response :unprocessable_entity
    assert @version.reload.draft?
  end

  test "known blockers link to cabin inventory, supplier rates, and agreement" do
    resource_id = @version.supplier_resource_definitions.sole.supplier_resource_id
    @version.capacity_pool_definitions.find_by!(capacity_pool: @pool).update!(proposed_opening_quantity: nil)
    @version.supplier_arrangement_cruise_agreement_confirmations.find_by!(current: true).update_columns(
      status: "provisional", confirmed_at: nil, confirmed_by_id: nil
    )
    sources = @version.supplier_cost_sources.where(supplier_resource_id: resource_id)
    @version.supplier_cost_definitions.where(supplier_cost_source_id: sources.select(:id)).delete_all
    sources.delete_all

    sign_in_as @staff
    get departure_arrangement_cruise_activation_path(@departure, @arrangement)

    assert_select "#cruise-activation-status", text: "Needs attention"
    assert_select "a[href=?]", edit_departure_arrangement_cruise_cabin_category_path(@departure, @arrangement, resource_id)
    assert_select "a[href=?]", departure_arrangement_cruise_agreement_path(@departure, @arrangement, focus: "agreement")
    rates_link = css_select("a").find { |link| link.text == "Open Supplier rates" }
    assert rates_link
    assert_includes rates_link["href"], resource_id
    assert_no_match "#cruise-rates", response.body
    assert_no_match "deposits-and-deadlines", response.body
    assert_no_match "What activation will do", response.body
    assert_no_match "Confirm and activate group", response.body
  end

  test "an unknown blocker links to advanced supplier planning" do
    sign_in_as @staff
    unknown = SupplierArrangementActivationReadiness::Blocker.new(
      track: :structure, code: :items_missing, path: "items", message: "Add at least one Arrangement Item."
    )
    real = SupplierArrangementActivationReadiness.new(
      agency: @agency, arrangement: @arrangement, version: @version.reload
    ).call
    replaced = SupplierArrangementActivationReadiness::Result.new(
      version: real.version, blockers: [ unknown ], cost_selections: real.cost_selections
    )
    readiness = Object.new
    readiness.define_singleton_method(:call) { replaced }

    with_constructor(SupplierArrangementActivationReadiness, readiness) do
      get departure_arrangement_cruise_activation_path(@departure, @arrangement)
    end

    assert_select "#cruise-activation-status", text: "Requires Advanced"
    assert_match "Add at least one Arrangement Item.", response.body
    assert_no_match "The Supplier setup is ready", response.body
    assert_select "a[href=?]", departure_arrangement_activation_path(@departure, @arrangement), text: "Open Advanced Supplier planning"
    assert_no_match "Confirm and activate group", response.body
  end

  test "a confirmed agreement stays complete while another blocker keeps review in needs attention" do
    @version.capacity_pool_definitions.find_by!(capacity_pool: @pool).update!(proposed_opening_quantity: nil)
    sign_in_as @staff
    get departure_arrangement_cruise_activation_path(@departure, @arrangement)

    assert_select "#cruise-activation-status", text: "Needs attention"
    assert_select "#cruise-activation-setup", text: /Agreement\s+Complete/
  end

  test "a successor draft is not labeled active" do
    sign_in_as @staff
    post departure_arrangement_cruise_activation_path(@departure, @arrangement), params: activation_params
    assert_redirected_to departure_arrangement_cruise_activation_path(@departure, @arrangement)

    CreateSupplierArrangementSuccessor.new(
      agency: @agency,
      actor: @staff,
      arrangement: @arrangement.reload,
      arrangement_lock_version: @arrangement.lock_version,
      version_lock_version: @version.reload.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call

    get departure_arrangement_cruise_activation_path(@departure, @arrangement)
    assert_response :success
    assert_select "#cruise-activation-status", text: "Needs attention"

    draft = @arrangement.versions.find_by!(status: "draft")
    RecordCruiseSupplierAgreement.new(
      agency: @agency,
      actor: @staff,
      arrangement: @arrangement,
      intent: "confirm",
      version_lock_version: draft.lock_version,
      idempotency_key: SecureRandom.uuid,
      group_reference: "2228888",
      group_creation_date: "2026-09-01",
      contract_date: "2026-09-13"
    ).call

    get departure_arrangement_cruise_activation_path(@departure, @arrangement)
    assert_select "#cruise-activation-status", text: "Ready to review"
    assert_match "remains in effect until activation succeeds", response.body
    assert_select "input[type=submit][value=?]", "Confirm and activate group"
    assert_select "input#supplier_reference[value='2228888']"
  end

  test "a viewer can read the review and cannot activate" do
    sign_in_as agency_users(:harbor_viewer)
    get departure_arrangement_cruise_activation_path(@departure, @arrangement)
    assert_response :success
    assert_select "#cruise-activation-status", text: "Ready to review"
    assert_no_match "Confirm and activate group", response.body
    assert_select "a[href=?]", departure_arrangement_cruise_cabin_categories_path(@departure, @arrangement), count: 0

    post departure_arrangement_cruise_activation_path(@departure, @arrangement), params: activation_params
    assert_redirected_to root_path
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
    assert_match "does not match the requirements on this review", response.body
    assert_match "already past due", response.body
    assert @version.reload.draft?
  end

  test "a signed elapsed review is rejected when another requirement elapses" do
    create_elapsed_deadline!
    sign_in_as @staff
    get departure_arrangement_cruise_activation_path(@departure, @arrangement)
    token = elapsed_review_token_from_response
    assert token.present?

    create_elapsed_deadline!(date: "2020-02-01")
    post departure_arrangement_cruise_activation_path(@departure, @arrangement), params: activation_params(
      elapsed_review_token: token,
      elapsed_deadlines_acknowledged: "1"
    )
    assert_response :unprocessable_entity
    assert_match "elapsed after this review was opened", response.body
    assert_match "already past due", response.body
    assert @version.reload.draft?
  end

  test "elapsed acknowledgment is submitted only from the checkbox" do
    create_elapsed_deadline!
    sign_in_as @staff
    get departure_arrangement_cruise_activation_path(@departure, @arrangement)
    token = elapsed_review_token_from_response
    assert token.present?

    post departure_arrangement_cruise_activation_path(@departure, @arrangement), params: activation_params(
      elapsed_review_token: token
    )
    assert_response :unprocessable_entity
    assert_match "already-elapsed", response.body
    assert @version.reload.draft?

    post departure_arrangement_cruise_activation_path(@departure, @arrangement), params: activation_params(
      elapsed_review_token: token,
      elapsed_deadlines_acknowledged: "1"
    )
    assert_redirected_to departure_arrangement_cruise_activation_path(@departure, @arrangement)
    assert @version.reload.activated?
  end

  test "a forged elapsed acknowledgment does not activate" do
    create_elapsed_deadline!
    sign_in_as @staff
    review = CompileCruiseActivationReview.new(
      agency: @agency, arrangement: @arrangement, version: @version.reload
    ).call
    assert_no_difference "SupplierArrangementActivation.count" do
      post departure_arrangement_cruise_activation_path(@departure, @arrangement), params: activation_params(
        elapsed_deadlines_acknowledged: "1"
      )
    end
    assert_response :unprocessable_entity
    assert_match "does not match the requirements on this review", response.body
    assert_no_match "already-elapsed", response.body
    assert @version.reload.draft?

    other_version_token = CruiseElapsedReviewToken.issue(
      agency_id: @agency.id,
      arrangement_version_id: SecureRandom.uuid,
      elapsed_definition_ids: review.elapsed.map(&:definition_id)
    )
    assert_no_difference "SupplierArrangementActivation.count" do
      post departure_arrangement_cruise_activation_path(@departure, @arrangement), params: activation_params(
        elapsed_review_token: other_version_token,
        elapsed_deadlines_acknowledged: "1"
      )
    end
    assert_response :unprocessable_entity
    assert_match "does not match the requirements on this review", response.body
    assert @version.reload.draft?
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

  test "a direct post without the acknowledgement writes nothing" do
    sign_in_as @staff
    assert_no_difference [ "SupplierConfirmation.count", "AuditEvent.count" ] do
      post departure_arrangement_cruise_activation_path(@departure, @arrangement), params: activation_params(
        terms_acknowledged: "0"
      )
    end
    assert_response :unprocessable_entity
    assert @version.reload.draft?
  end

  test "a cleared supplier reference survives a failed post" do
    sign_in_as @staff
    post departure_arrangement_cruise_activation_path(@departure, @arrangement), params: activation_params(
      supplier_reference: "",
      version_lock_version: @version.lock_version.to_i + 5
    )
    assert_response :unprocessable_entity
    assert_select "input#supplier_reference[value='1119999']", count: 0
    assert_select "input#supplier_reference"
  end

  test "other proof without a description writes nothing" do
    sign_in_as @staff
    assert_no_difference "SupplierConfirmation.count" do
      post departure_arrangement_cruise_activation_path(@departure, @arrangement), params: activation_params(
        confirmation: { evidence_kind: "other", other_evidence_label: "" }
      )
    end
    assert_response :unprocessable_entity
    assert @version.reload.draft?
  end

  test "a forged relaxed confirmation flag is rejected" do
    sign_in_as @staff
    assert_no_difference [ "SupplierConfirmation.count", "SupplierArrangementActivation.count" ] do
      post departure_arrangement_cruise_activation_path(@departure, @arrangement), params: activation_params(
        allow_relaxed_confirmation: "1"
      )
    end
    assert_response :unprocessable_entity
    assert_match "cannot be selected", response.body
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

  def elapsed_review_token_from_response
    css_select("input[name='elapsed_review_token']").first&.[]("value")
  end

  def create_elapsed_deadline!(date: "2020-01-01")
    CreateSupplierDeadlineDefinition.new(
      agency: @agency,
      actor: @staff,
      version: @version.reload,
      attributes: {
        deadline_type: "option_or_release_date",
        kind: "actionable",
        rule_shape: "fixed_date",
        rule_parameters: { "date" => date },
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
      terms_acknowledged: "1",
      confirmation: {
        evidence_kind: "supplier_confirmation",
        evidence_on: Date.current.to_s,
        channel: "portal",
        reference_note: "Supplier approved the terms"
      }
    }.deep_merge(overrides)
  end
end
