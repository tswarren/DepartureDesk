# frozen_string_literal: true

require "test_helper"

class CompileCruiseCompositionSummaryTest < ActiveSupport::TestCase
  setup do
    @agency = agencies(:harbor)
    @actor = agency_users(:harbor_staff)
    @departure = create_capacity_departure(@agency, name: "Smith Family Cruise")
    @contractor = create_capacity_supplier(@agency, "Celebrity Cruises")
    @provider = create_capacity_supplier(@agency, "Celebrity Ship Ops")
    sailing = CreateCruiseSailingSetup.new(
      agency: @agency,
      actor: @actor,
      departure: @departure,
      arrangement_attributes: {
        name: "Celebrity group agreement",
        contracting_supplier_id: @contractor.id
      },
      item_attributes: {
        name: "Celebrity Beyond",
        default_service_provider_id: @provider.id
      },
      occurrence_attributes: {
        name: "Eastern Caribbean",
        starts_on: "2027-11-06",
        ends_on: "2027-11-13",
        time_zone: "America/New_York"
      },
      idempotency_key: SecureRandom.uuid
    ).call
    @arrangement = sailing.record.arrangement
    @version = @arrangement.versions.sole
  end

  test "a new cruise recommends cabin categories and retains every readiness blocker" do
    summary = compile
    readiness = SupplierArrangementActivationReadiness.new(
      agency: @agency, arrangement: @arrangement, version: @version
    ).call

    assert_equal :add_cabins, summary.recommended_next_action.key
    assert_equal "Add cabin categories", summary.recommended_next_action.label
    assert_equal readiness.blockers.map(&:code), summary.activation.blockers.map(&:code)
    assert_includes summary.activation.blockers.map(&:code), :cruise_agreement_unconfirmed
    assert_equal "Not ready", summary.sections.find { |section| section.key == "activation" }.status_label
    assert_equal "Not recorded", summary.sections.find { |section| section.key == "agreement" }.status_label
    assert_equal "Not recorded", summary.sections.find { |section| section.key == "requirements" }.status_label
    assert summary.term_rows.none?(&:recorded)
  end

  test "a cabin without rates recommends supplier rates" do
    add_cabin!
    summary = compile

    assert_equal :add_rates, summary.recommended_next_action.key
    assert_match(/O1/, summary.recommended_next_action.detail)
    assert_equal "1 · 8 cabins", summary.sections.find { |section| section.key == "cabins" }.detail
  end

  test "estimated rates recommend the agreement while every blocker stays listed" do
    add_cabin!
    add_estimate!
    summary = compile
    codes = summary.activation.blockers.map(&:code)

    assert_equal :record_agreement, summary.recommended_next_action.key
    assert_includes codes, :cruise_agreement_unconfirmed
    assert_includes codes, :cruise_contracted_rates_missing
    assert_equal "1 estimated", summary.sections.find { |section| section.key == "rates" }.detail
  end

  test "a confirmed agreement with estimated rates names requirements without hiding them" do
    add_cabin!
    add_estimate!
    confirm!
    summary = compile

    assert_equal :review_contracted_rates, summary.recommended_next_action.key
    assert_match(/Supplier requirements still need attention/, summary.recommended_next_action.detail)
    assert_match(/Confirmed/, summary.sections.find { |section| section.key == "agreement" }.status_label)
  end

  test "presentation priority picks one blocker and leaves the rest in order" do
    first = blocker(:cruise_contracted_rates_missing, "resources.later")
    earlier_cabin = blocker(:cruise_contracted_rates_missing, "resources.earlier")
    agreement = blocker(:cruise_agreement_unconfirmed, "cruise_agreement")
    treatment = blocker(:cruise_deposit_treatment_missing, "cruise_agreement")
    generic = blocker(:opening_authority_incomplete, "pools.1")
    definitions = [
      Struct.new(:id, :position).new("later", 2),
      Struct.new(:id, :position).new("earlier", 1)
    ]

    chosen = CompileCruiseCompositionSummary.presentation_blocker(
      [ first, generic, agreement, earlier_cabin, treatment ],
      resource_definitions: definitions
    )
    assert_equal :cruise_agreement_unconfirmed, chosen.code

    chosen = CompileCruiseCompositionSummary.presentation_blocker(
      [ first, earlier_cabin, treatment ],
      resource_definitions: definitions
    )
    assert_equal "resources.earlier", chosen.path

    chosen = CompileCruiseCompositionSummary.presentation_blocker(
      [ generic, treatment ],
      resource_definitions: definitions
    )
    assert_equal :cruise_deposit_treatment_missing, chosen.code

    chosen = CompileCruiseCompositionSummary.presentation_blocker([ generic, blocker(:pairs_incomplete, "items.1") ])
    assert_equal :opening_authority_incomplete, chosen.code
  end

  private

  def compile
    shape = DetectCruiseArrangementShape.new(agency: @agency, arrangement: @arrangement).call
    CompileCruiseCompositionSummary.new(agency: @agency, arrangement: @arrangement, shape: shape).call
  end

  def blocker(code, path)
    SupplierArrangementActivationReadiness::Blocker.new(track: :structure, code: code, path: path, message: code.to_s)
  end

  def add_cabin!
    CreateCruiseCabinCategorySetup.new(
      agency: @agency,
      actor: @actor,
      arrangement: @arrangement,
      resource_attributes: { name: "Prime Oceanview", supplier_code: "O1", maximum_occupancy: 3 },
      pool_attributes: { inventory_mode: "block", proposed_opening_quantity: 8 },
      version_lock_version: @version.reload.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call
  end

  def add_estimate!
    CreateCruiseSupplierRateSchedule.new(
      agency: @agency,
      actor: @actor,
      arrangement: @arrangement,
      resource: @arrangement.supplier_resources.sole,
      terms: {
        first_second_fare: "1624.00",
        additional_fare: "406.00",
        single_supplement: "1624.00",
        nccf: "320.00",
        first_second_discount: "150.00",
        additional_discount: "37.50",
        taxes_fees: "137.00"
      },
      commission: { method: "not_provided" },
      stage: "estimate",
      version_lock_version: @version.reload.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call
  end

  def confirm!
    RecordCruiseSupplierAgreement.new(
      agency: @agency,
      actor: @actor,
      arrangement: @arrangement,
      intent: "confirm",
      version_lock_version: @version.reload.lock_version,
      idempotency_key: SecureRandom.uuid,
      group_reference: "1119999",
      contract_date: "2026-09-13",
      group_creation_date: "2026-09-13"
    ).call
  end
end
