# frozen_string_literal: true

require "test_helper"

class M4d1CruiseAgreementRequirementsRequestTest < ActionDispatch::IntegrationTest
  include CapacityGraphHelper

  setup do
    @agency = agencies(:harbor)
    @staff = agency_users(:harbor_staff)
    @contractor = create_capacity_supplier(@agency, "Celebrity Cruises")
    @departure = create_capacity_departure(@agency, name: "Smith Family Cruise")
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
    @arrangement = sailing.record.arrangement
    @version = @arrangement.versions.sole
    @pools = []
    [
      [ "E3", "Deluxe Oceanview" ],
      [ "O1", "Prime Oceanview" ],
      [ "DI", "Inside" ]
    ].each do |code, name|
      cabin = CreateCruiseCabinCategorySetup.new(
        agency: @agency,
        actor: @staff,
        arrangement: @arrangement,
        resource_attributes: { name: name, supplier_code: code, maximum_occupancy: 3 },
        pool_attributes: {
          inventory_mode: "block",
          proposed_opening_quantity: 8,
          evidence_kind: "contract",
          evidence_on: Date.current,
          evidence_reference_note: "Signed cabin block"
        },
        version_lock_version: @version.reload.lock_version,
        idempotency_key: SecureRandom.uuid
      ).call
      @pools << cabin.record.pool
    end
    @version.reload
  end

  test "blank allocated credit is rejected and is not stored as zero" do
    sign_in_as @staff
    assert_no_difference -> { SupplierArrangementCruiseTermDefinition.count } do
      post terms_departure_arrangement_cruise_agreement_path(@departure, @arrangement), params: {
        term_scope: "allocated",
        version_lock_version: @version.lock_version,
        idempotency_key: SecureRandom.uuid,
        allocated_amount: "500.00",
        allocated_credit: "",
        allocated_body: "Policy wording"
      }
    end
    assert_response :unprocessable_entity
    assert_match "Enter the allocated-cabin amount, credit, currency, and wording.", response.body
  end

  test "cancellation edits submit the complete ladder and an empty list clears it" do
    sign_in_as @staff
    post terms_departure_arrangement_cruise_agreement_path(@departure, @arrangement), params: {
      term_scope: "cancellation",
      version_lock_version: @version.reload.lock_version,
      idempotency_key: SecureRandom.uuid,
      cancellation_steps: [
        { days_before_departure: "120", body: "Deposit becomes non-refundable." },
        { days_before_departure: "90", body: "Additional penalties apply." }
      ]
    }
    assert_redirected_to departure_arrangement_cruise_agreement_path(@departure, @arrangement, highlight: "term-cancellation")
    steps = @version.supplier_arrangement_cruise_term_definitions.where(term_type: "cancellation_step").order(:position)
    assert_equal [ 120, 90 ], steps.map(&:days_before_departure)

    post terms_departure_arrangement_cruise_agreement_path(@departure, @arrangement), params: {
      term_scope: "cancellation",
      version_lock_version: @version.reload.lock_version,
      idempotency_key: SecureRandom.uuid,
      cancellation_steps: [
        { days_before_departure: "120", body: "Deposit becomes non-refundable." },
        { days_before_departure: "90", body: "Penalties revised." }
      ]
    }
    assert_equal [ "Deposit becomes non-refundable.", "Penalties revised." ],
      @version.supplier_arrangement_cruise_term_definitions.where(term_type: "cancellation_step").order(:position).map(&:body)

    post terms_departure_arrangement_cruise_agreement_path(@departure, @arrangement), params: {
      term_scope: "allocated",
      version_lock_version: @version.reload.lock_version,
      idempotency_key: SecureRandom.uuid,
      allocated_amount: "500.00",
      allocated_credit: "50.00",
      allocated_body: "Allocated policy"
    }
    assert_equal 2, @version.supplier_arrangement_cruise_term_definitions.where(term_type: "cancellation_step").count

    key = SecureRandom.uuid
    post terms_departure_arrangement_cruise_agreement_path(@departure, @arrangement), params: {
      term_scope: "cancellation",
      version_lock_version: @version.reload.lock_version,
      idempotency_key: key
    }
    assert_empty @version.supplier_arrangement_cruise_term_definitions.where(term_type: "cancellation_step")
    assert @version.supplier_arrangement_cruise_term_definitions.exists?(term_type: "allocated_cabin_deposit")

    post terms_departure_arrangement_cruise_agreement_path(@departure, @arrangement), params: {
      term_scope: "cancellation",
      version_lock_version: @version.reload.lock_version,
      idempotency_key: key
    }
    assert_response :redirect
    assert_empty @version.supplier_arrangement_cruise_term_definitions.where(term_type: "cancellation_step")
  end

  test "focused cancellation forms keep the other steps when one step changes" do
    sign_in_as @staff
    post terms_departure_arrangement_cruise_agreement_path(@departure, @arrangement), params: {
      term_scope: "cancellation",
      version_lock_version: @version.lock_version,
      idempotency_key: SecureRandom.uuid,
      cancellation_steps: [
        { days_before_departure: "120", body: "First step stays." },
        { days_before_departure: "90", body: "Second step changes." }
      ]
    }
    assert_response :redirect

    get departure_arrangement_cruise_agreement_path(@departure, @arrangement, focus: "cancellation-edit-2")
    assert_response :success
    assert_select "input[type=hidden][name='cancellation_steps[][days_before_departure]'][value='120']"
    assert_select "input[type=hidden][name='cancellation_steps[][body]'][value=?]", "First step stays."
    assert_select "textarea[name='cancellation_steps[][body]']", text: "Second step changes."

    post terms_departure_arrangement_cruise_agreement_path(@departure, @arrangement), params: {
      term_scope: "cancellation",
      version_lock_version: @version.reload.lock_version,
      idempotency_key: SecureRandom.uuid,
      cancellation_steps: [
        { days_before_departure: "120", body: "First step stays." },
        { days_before_departure: "90", body: "Second step revised." }
      ]
    }
    assert_equal [ "First step stays.", "Second step revised." ], cancellation_bodies

    get departure_arrangement_cruise_agreement_path(@departure, @arrangement, focus: "cancellation-new")
    assert_select "input[type=hidden][name='cancellation_steps[][body]'][value=?]", "First step stays."
    assert_select "input[type=hidden][name='cancellation_steps[][body]'][value=?]", "Second step revised."

    post terms_departure_arrangement_cruise_agreement_path(@departure, @arrangement), params: {
      term_scope: "cancellation",
      version_lock_version: @version.reload.lock_version,
      idempotency_key: SecureRandom.uuid,
      cancellation_steps: [
        { days_before_departure: "120", body: "First step stays." },
        { days_before_departure: "90", body: "Second step revised." },
        { days_before_departure: "60", body: "Third step added." }
      ]
    }
    assert_equal [ 120, 90, 60 ], cancellation_days
    assert_equal [ "First step stays.", "Second step revised.", "Third step added." ], cancellation_bodies

    get departure_arrangement_cruise_agreement_path(@departure, @arrangement)
    removal = css_select("form.dd-agreement-inline-form").find { |form|
      form.css("input[name='cancellation_steps[][days_before_departure]']").map { |field| field["value"] } == [ "120", "60" ]
    }
    assert removal
    assert_equal [ "First step stays.", "Third step added." ],
      removal.css("input[name='cancellation_steps[][body]']").map { |field| field["value"] }

    post terms_departure_arrangement_cruise_agreement_path(@departure, @arrangement), params: {
      term_scope: "cancellation",
      version_lock_version: @version.reload.lock_version,
      idempotency_key: SecureRandom.uuid,
      cancellation_steps: [
        { days_before_departure: "120", body: "First step stays." },
        { days_before_departure: "60", body: "Third step added." }
      ]
    }
    assert_equal [ 120, 60 ], cancellation_days
    assert_equal [ "First step stays.", "Third step added." ], cancellation_bodies
  end

  test "an omitted citation is preserved and the agreement page does not edit it" do
    sign_in_as @staff
    RecordCruiseCommercialBenefit.new(
      agency: @agency,
      actor: @staff,
      arrangement: @arrangement,
      term_type: "tour_conductor_credit",
      body: "1 credit per 16 guests.",
      source_citation: "July 2025 brochure",
      version_lock_version: @version.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call
    benefit = @version.supplier_arrangement_commercial_benefit_definitions.find_by!(term_type: "tour_conductor_credit")

    patch departure_arrangement_cruise_commercial_benefit_path(@departure, @arrangement, "tour_conductor_credit"), params: {
      version_lock_version: @version.reload.lock_version,
      definition_lock_version: benefit.lock_version,
      idempotency_key: SecureRandom.uuid,
      commercial_benefit: { term_type: "tour_conductor_credit", body: "1 credit per 16 full-tariff guests." }
    }
    assert_equal "July 2025 brochure", benefit.reload.source_citation
    assert_equal "1 credit per 16 full-tariff guests.", benefit.body

    get departure_arrangement_cruise_agreement_path(@departure, @arrangement)
    assert_match "Source information recorded", response.body
    assert_no_match "Manage source", response.body
    assert_no_match "Source citation", response.body
  end

  test "agreement deadline saves preserve an omitted description and only agreement is a return token" do
    sign_in_as @staff
    post departure_arrangement_cruise_deposits_and_deadlines_deadlines_path(@departure, @arrangement), params: {
      version_lock_version: @version.lock_version,
      idempotency_key: SecureRandom.uuid,
      cruise_deadline: {
        template: "final_payment",
        kind: "actionable",
        description: "Keep this final-payment note",
        rule_shape: "fixed_date",
        fixed_date: "2027-08-08",
        coverage_scope: "arrangement"
      }
    }
    assert_response :redirect
    assert_match %r{/cruise/deposits-and-deadlines}, @response.redirect_url
    deadline = @version.supplier_deadline_definitions.order(:position).last
    assert_equal "Keep this final-payment note", deadline.description

    patch departure_arrangement_cruise_deposits_and_deadlines_deadline_path(@departure, @arrangement, deadline), params: {
      return_to: "https://example.invalid/phish",
      lock_version: deadline.lock_version,
      cruise_deadline: {
        template: "final_payment",
        kind: "actionable",
        description: "Keep this final-payment note",
        rule_shape: "fixed_date",
        fixed_date: "2027-08-01",
        coverage_scope: "arrangement"
      }
    }
    assert_match %r{/cruise/deposits-and-deadlines}, @response.redirect_url
    assert_equal "Keep this final-payment note", deadline.reload.description

    patch departure_arrangement_cruise_deposits_and_deadlines_deadline_path(@departure, @arrangement, deadline), params: {
      return_to: "agreement",
      lock_version: deadline.reload.lock_version,
      cruise_deadline: {
        template: "final_payment",
        kind: "actionable",
        rule_shape: "fixed_date",
        fixed_date: "2027-08-08",
        coverage_scope: "arrangement"
      }
    }
    assert_redirected_to departure_arrangement_cruise_agreement_path(
      @departure, @arrangement, highlight: "deadline-#{deadline.id}"
    )
    assert_equal "Keep this final-payment note", deadline.reload.description
    assert_equal "2027-08-08", deadline.rule_parameters["date"]
  end

  test "the initial deposit total follows current opening quantity and an extra requirement stays visible" do
    sign_in_as @staff
    on_request = CreateCruiseCabinCategorySetup.new(
      agency: @agency,
      actor: @staff,
      arrangement: @arrangement,
      resource_attributes: {
        name: "Concierge on request",
        supplier_code: "C1",
        maximum_occupancy: 2
      },
      pool_attributes: {
        inventory_mode: "on_request",
        evidence_kind: "contract",
        evidence_on: Date.current,
        evidence_reference_note: "On request cabin"
      },
      version_lock_version: @version.reload.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call
    on_request_definition = @version.reload.capacity_pool_definitions.find_by!(
      capacity_pool_id: on_request.record.pool.id
    )
    assert_nil on_request_definition.proposed_opening_quantity

    post departure_arrangement_cruise_deposits_and_deadlines_deposits_path(@departure, @arrangement), params: {
      return_to: "agreement",
      version_lock_version: @version.lock_version,
      idempotency_key: SecureRandom.uuid,
      cruise_deposit: {
        template: "initial_deposit",
        amount_shape: "quantity_times_rate",
        quantity_basis: "capacity_pool_units",
        rate_amount: "50.00",
        rule_shape: "fixed_date",
        fixed_date: "2026-10-13",
        capacity_pool_ids: @pools.map(&:id) + [ on_request.record.pool.id ]
      }
    }
    deposit = @version.supplier_deposit_requirement_definitions.order(:position).last
    assert_redirected_to departure_arrangement_cruise_agreement_path(
      @departure, @arrangement, highlight: "deposit-#{deposit.id}"
    )
    assert_equal 5_000, deposit.rate_minor_units
    assert_nil deposit.explicit_quantity
    follow_redirect!
    assert_match "$50.00 per opening cabin × 24 cabins = $1,200.00", response.body
    assert_match "1 selected category has quantity not tracked.", response.body
    assert_nil on_request_definition.reload.proposed_opening_quantity

    @version.capacity_pool_definitions.find_by!(capacity_pool_id: @pools.last.id).update!(proposed_opening_quantity: 10)
    get departure_arrangement_cruise_agreement_path(@departure, @arrangement)
    assert_match "$50.00 per opening cabin × 26 cabins = $1,300.00", response.body
    assert_match "1 selected category has quantity not tracked.", response.body
    assert_equal 5_000, deposit.reload.rate_minor_units
    assert_equal "2026-10-13", deposit.rule_parameters["date"]

    post departure_arrangement_cruise_deposits_and_deadlines_deadlines_path(@departure, @arrangement), params: {
      version_lock_version: @version.reload.lock_version,
      idempotency_key: SecureRandom.uuid,
      cruise_deadline: {
        template: "rooming_list",
        kind: "informational",
        rule_shape: "fixed_date",
        fixed_date: "2027-10-01",
        coverage_scope: "arrangement"
      }
    }
    get departure_arrangement_cruise_agreement_path(@departure, @arrangement)
    assert_match "Additional Supplier requirement — Review in Advanced", response.body
    assert_match "Rooming list", response.body
  end

  test "provisional identity keeps group creation and contract dates distinct" do
    sign_in_as @staff
    RecordCruiseSupplierAgreement.new(
      agency: @agency,
      actor: @staff,
      arrangement: @arrangement,
      intent: "save_provisional",
      version_lock_version: @version.lock_version,
      idempotency_key: SecureRandom.uuid,
      group_reference: "1119999",
      group_creation_date: "2026-09-01"
    ).call

    get departure_arrangement_cruise_agreement_path(@departure, @arrangement)
    assert_response :success
    assert_match "Group 1119999", response.body
    assert_match "Group creation date", response.body
    assert_match "September 1, 2026", response.body
    assert_no_match(/Contract date/, response.body)
    assert_select "#cruise-step-agreement .dd-journey-step__status", text: "Needs attention"
  end

  test "correcting a confirmation keeps the earlier group number in history" do
    sign_in_as @staff
    RecordCruiseSupplierAgreement.new(
      agency: @agency,
      actor: @staff,
      arrangement: @arrangement,
      intent: "confirm",
      version_lock_version: @version.lock_version,
      idempotency_key: SecureRandom.uuid,
      group_reference: "1119999",
      group_creation_date: "2026-09-01",
      contract_date: "2026-09-13"
    ).call
    RecordCruiseSupplierAgreement.new(
      agency: @agency,
      actor: @staff,
      arrangement: @arrangement,
      intent: "correct",
      version_lock_version: @version.reload.lock_version,
      idempotency_key: SecureRandom.uuid,
      group_reference: "1119998",
      group_creation_date: "2026-09-01",
      contract_date: "2026-09-13"
    ).call

    get departure_arrangement_cruise_agreement_path(@departure, @arrangement)
    assert_response :success
    assert_select "summary", text: "View history"
    assert_match "Group 1119998", response.body
    assert_match "Group 1119999", response.body
    assert_equal "1119999", @version.supplier_arrangement_cruise_agreement_confirmations.find_by!(current: false).group_reference
  end

  test "unrecorded agreement rows stay in one list and provisional history stays undated" do
    sign_in_as @staff
    get departure_arrangement_cruise_agreement_path(@departure, @arrangement)
    assert_response :success
    assert_select "section[aria-labelledby=deposits] h3", text: "Not recorded"
    assert_select "a[href=?]", departure_arrangement_cruise_agreement_path(@departure, @arrangement, focus: "deposit-new-initial"), text: "Add"
    assert_select "a[href=?]", departure_arrangement_cruise_agreement_path(@departure, @arrangement, focus: "term-allocated"), text: "Add"
    assert_select "section[aria-labelledby=deadlines] a[href=?]", departure_arrangement_cruise_agreement_path(@departure, @arrangement, focus: "deadline-new-hard-stop"), text: "Add"
    assert_select "section[aria-labelledby=deadlines] a[href=?]", departure_arrangement_cruise_agreement_path(@departure, @arrangement, focus: "deadline-new-final-payment"), text: "Add"
    assert_select "a[href=?]", departure_arrangement_cruise_agreement_path(@departure, @arrangement, focus: "cancellation-new"), text: "Add step"
    assert_no_match(/Suggested due date:/, response.body)

    RecordCruiseSupplierAgreement.new(
      agency: @agency,
      actor: @staff,
      arrangement: @arrangement,
      intent: "confirm",
      version_lock_version: @version.lock_version,
      idempotency_key: SecureRandom.uuid,
      group_reference: "1119998",
      group_creation_date: "2026-09-01",
      contract_date: "2026-09-13",
      note: "Current note"
    ).call
    current = @version.supplier_arrangement_cruise_agreement_confirmations.find_by!(current: true)
    SupplierArrangementCruiseAgreementConfirmation.create!(
      agency: @agency,
      departure: @departure,
      supplier_arrangement: @arrangement,
      supplier_arrangement_version: @version,
      status: "provisional",
      current: false,
      group_creation_date: Date.new(2026, 8, 1),
      group_reference: "1119000",
      note: "Earlier provisional note",
      corrects: nil
    )

    get departure_arrangement_cruise_agreement_path(@departure, @arrangement)
    assert_response :success
    assert_select "dt", text: "Confirmation recorded"
    assert_select "summary", text: "View history"
    assert_match "Suggested due date:", response.body
    assert_no_match(/<td>\s*Suggested due date/m, response.body)
    assert_match "Not confirmed", response.body
    assert_match "Group 1119000", response.body
    assert_match "Earlier provisional note", response.body
    assert_no_match(/Not confirmed.+(\d{1,2}:\d{2})/m, response.body)
    assert current.confirmed?
  end

  test "an all-nonnumeric initial deposit does not evaluate to zero" do
    sign_in_as @staff
    cabin = CreateCruiseCabinCategorySetup.new(
      agency: @agency,
      actor: @staff,
      arrangement: @arrangement,
      resource_attributes: { name: "On request", supplier_code: "RQ", maximum_occupancy: 2 },
      pool_attributes: { inventory_mode: "on_request" },
      version_lock_version: @version.reload.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call

    post departure_arrangement_cruise_deposits_and_deadlines_deposits_path(@departure, @arrangement), params: {
      return_to: "agreement",
      version_lock_version: @version.reload.lock_version,
      idempotency_key: SecureRandom.uuid,
      cruise_deposit: {
        template: "initial_deposit",
        amount_shape: "quantity_times_rate",
        quantity_basis: "capacity_pool_units",
        rate_amount: "50.00",
        rule_shape: "fixed_date",
        fixed_date: "2026-10-13",
        capacity_pool_ids: [ cabin.record.pool.id ]
      }
    }
    deposit = @version.supplier_deposit_requirement_definitions.order(:position).last
    follow_redirect!
    assert_match "No applicable numeric opening quantity", response.body
    assert_no_match "$0", response.body
    assert_equal 5_000, deposit.rate_minor_units
    assert_nil deposit.explicit_quantity
  end

  test "a command error keeps submitted agreement values in the summary" do
    sign_in_as @staff
    post confirm_departure_arrangement_cruise_agreement_path(@departure, @arrangement), params: {
      version_lock_version: @version.lock_version,
      idempotency_key: SecureRandom.uuid,
      group_creation_date: "2026-09-01",
      group_reference: "",
      contract_date: "2026-09-02",
      note: "Hold this note"
    }

    assert_response :unprocessable_entity
    assert_select "#form-error-summary", text: /Enter the group reference/
    assert_select "textarea#agreement_note", text: "Hold this note"
    assert_select "input#agreement_group_creation_date_confirm[value=?]", "2026-09-01"
  end

  private

  def cancellation_bodies
    @version.supplier_arrangement_cruise_term_definitions.where(term_type: "cancellation_step").order(:position).map(&:body)
  end

  def cancellation_days
    @version.supplier_arrangement_cruise_term_definitions.where(term_type: "cancellation_step").order(:position).map(&:days_before_departure)
  end
end
