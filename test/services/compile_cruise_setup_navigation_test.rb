# frozen_string_literal: true

require "test_helper"

class CompileCruiseSetupNavigationTest < ActiveSupport::TestCase
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

  test "a missing confirmation stays Not started and is not an attention item" do
    navigation = compile

    assert_equal "Complete", status_for(navigation, :sailing)
    assert_equal "Not started", status_for(navigation, :cabins)
    assert_equal "Not started", status_for(navigation, :rates)
    assert_equal "Not started", status_for(navigation, :agreement)
    assert_equal "Needs attention", status_for(navigation, :review)
    assert_not_includes navigation.attention_items.map(&:code), :cruise_agreement_unconfirmed
    assert navigation.attention_items.none? { |item| item.code == :cruise_contracted_rates_missing }
  end

  test "a provisional confirmation and incomplete opening appear together" do
    add_cabin!
    RecordCruiseSupplierAgreement.new(
      agency: @agency,
      actor: @actor,
      arrangement: @arrangement,
      intent: "save_provisional",
      version_lock_version: @version.reload.lock_version,
      idempotency_key: SecureRandom.uuid,
      group_creation_date: "2026-09-13"
    ).call

    navigation = compile
    codes = navigation.attention_items.map(&:code)

    assert_equal "Needs attention", status_for(navigation, :agreement)
    assert_equal "Complete", status_for(navigation, :cabins)
    assert_includes codes, :cruise_agreement_unconfirmed
    assert_not_includes codes, :opening_authority_incomplete
    assert_not_includes codes, :cruise_contracted_rates_missing
  end

  test "a confirmed agreement stays complete when the initial deposit is not recorded" do
    add_cabin!
    RecordCruiseSupplierAgreement.new(
      agency: @agency,
      actor: @actor,
      arrangement: @arrangement,
      intent: "confirm",
      version_lock_version: @version.reload.lock_version,
      idempotency_key: SecureRandom.uuid,
      group_reference: "1119999",
      group_creation_date: "2026-09-01",
      contract_date: "2026-09-13"
    ).call

    navigation = compile

    assert_equal "Complete", status_for(navigation, :agreement)
    assert_equal "Needs attention", status_for(navigation, :review)
    assert_not_includes navigation.attention_items.map(&:code), :cruise_deposit_treatment_missing
  end

  test "a ready estimate is not an attention item" do
    add_cabin!
    add_estimate!

    navigation = compile

    assert_equal "Needs attention", status_for(navigation, :rates)
    assert_not_includes navigation.attention_items.map(&:code), :cruise_contracted_rates_missing
  end

  private

  def compile
    shape = DetectCruiseArrangementShape.new(agency: @agency, arrangement: @arrangement).call
    CompileCruiseSetupNavigation.new(agency: @agency, arrangement: @arrangement, shape: shape).call
  end

  def status_for(navigation, key)
    navigation.areas.find { |area| area.key == key }.status
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
end
