# frozen_string_literal: true

require "application_system_test_case"

class M4d1CruiseActivationSystemTest < ApplicationSystemTestCase
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
    @version.capacity_pool_definitions.find_by!(capacity_pool: @pool).update!(proposed_opening_quantity: nil)
  end

  test "a blocked cruise review leads to activation and the client service" do
    sign_in_from_browser(@staff)
    resize_window(1280)
    visit departure_arrangement_cruise_path(@departure, @arrangement)
    click_on "Review & activate"
    assert_text "does not have an opening cabin quantity"
    assert_text "Needs attention"
    assert_no_button "Confirm and activate group"
    assert_no_selector "table"
    assert_no_page_overflow

    resize_window(375)
    assert_no_page_overflow

    @version.capacity_pool_definitions.find_by!(capacity_pool: @pool).update!(proposed_opening_quantity: 8)
    satisfy_cruise_activation_gate!(
      agency: @agency, actor: @staff, arrangement: @arrangement, version: @version.reload
    )
    resize_window(1280)
    visit departure_arrangement_cruise_activation_path(@departure, @arrangement)
    assert_text "Ready to review"
    assert_selector "table"
    [ 375, 768, 1280, 1400 ].each do |width|
      resize_window(width)
      assert_no_page_overflow
    end
    resize_window(1280)
    select "Supplier confirmation", from: "Proof type"
    check "The inventory and rates shown are the Supplier agreement being activated for this exact version."
    click_on "Confirm and activate group"
    assert_text "Version #{@version.reload.version_number} became governing"
    click_on "Connect to Client service"
    assert_current_path departure_arrangement_cruise_service_connection_path(@departure, @arrangement)
  end
end
