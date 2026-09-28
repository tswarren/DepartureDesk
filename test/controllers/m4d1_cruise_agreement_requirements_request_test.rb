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

  test "an omitted citation is preserved and manage source can replace or clear it" do
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

    patch departure_arrangement_cruise_commercial_benefit_path(@departure, @arrangement, "tour_conductor_credit"), params: {
      version_lock_version: @version.reload.lock_version,
      definition_lock_version: benefit.reload.lock_version,
      idempotency_key: SecureRandom.uuid,
      benefit_editor: "benefit-source-tour_conductor_credit",
      commercial_benefit: {
        term_type: "tour_conductor_credit",
        body: benefit.body,
        source_citation: "Corrected brochure"
      }
    }
    assert_equal "Corrected brochure", benefit.reload.source_citation

    patch departure_arrangement_cruise_commercial_benefit_path(@departure, @arrangement, "tour_conductor_credit"), params: {
      version_lock_version: @version.reload.lock_version,
      definition_lock_version: benefit.reload.lock_version,
      idempotency_key: SecureRandom.uuid,
      commercial_benefit: {
        term_type: "tour_conductor_credit",
        body: benefit.body,
        source_citation: ""
      }
    }
    assert_nil benefit.reload.source_citation
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
        capacity_pool_ids: @pools.map(&:id)
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

    @version.capacity_pool_definitions.find_by!(capacity_pool_id: @pools.last.id).update!(proposed_opening_quantity: 10)
    get departure_arrangement_cruise_agreement_path(@departure, @arrangement)
    assert_match "$50.00 per opening cabin × 26 cabins = $1,300.00", response.body
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
end
