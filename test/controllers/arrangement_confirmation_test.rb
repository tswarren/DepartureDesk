require "test_helper"

# Confirm page and supply forms (SUP-12, INV-26).
class ArrangementConfirmationTest < ActionDispatch::IntegrationTest
  setup do
    @agency = agencies(:harbor)
    @admin = agency_users(:harbor_admin)
    @departure = CreateDeparture.new(agency: @agency, actor: @admin, attributes: { name: "Confirm Routes", operating_currency: "USD", time_zone: "America/New_York" }).call.record
    supplier = CreateSupplier.new(agency: @agency, actor: @admin, kind: "organization", names: { display_name: "Confirm Supplier" }, categories: [ "cruise_line" ]).call.record
    @payee = SavePayeeAccount.new(agency: @agency, actor: @admin, supplier:, attributes: { name: "USD", currency: "USD" }).call.record
    @arrangement = CreateSupplierArrangement.new(agency: @agency, actor: @admin, departure: @departure, supplier_id: supplier.id).call.record
    @group = SaveInventoryGroup.new(agency: @agency, actor: @admin, departure: @departure, arrangement: @arrangement,
      attributes: { label: "V01", service_category: "cruise", quantity: "8", positions_per_unit: "3", starts_on: "2027-11-06", ends_on: "2027-11-13" }).call.record
  end

  test "the Confirm page lists blockers, then confirms and shows the shells" do
    sign_in_as @admin
    get departure_arrangement_confirmation_path(@departure, @arrangement)
    assert_select "li", text: "Choose a payee account."

    UpdateSupplierArrangement.new(agency: @agency, actor: @admin, departure: @departure, arrangement: @arrangement,
      attributes: { group_reference: "GRP-9", payee_account_id: @payee.id }, lock_version: @arrangement.lock_version).call
    get departure_arrangement_confirmation_path(@departure, @arrangement)
    assert_select "p", text: /create 8 shells across 1 inventory group/

    post departure_arrangement_confirmation_path(@departure, @arrangement), params: { confirmed_on: "2026-11-01", confirmation_note: "Signed", lock_version: @arrangement.reload.lock_version }
    assert_redirected_to departure_arrangement_path(@departure, @arrangement)
    get departure_arrangement_group_path(@departure, @arrangement, @group)
    assert_select ".dd-shell", 8
    assert_select ".dd-shell-status", text: "Available", count: 8

    post departure_arrangement_group_capacity_events_path(@departure, @arrangement, @group),
      params: { kind: "increase", quantity: "1", evidence_note: "Extra cabin", idempotency_key: "k-1" }
    post departure_arrangement_group_capacity_events_path(@departure, @arrangement, @group),
      params: { kind: "increase", quantity: "1", evidence_note: "Extra cabin", idempotency_key: "k-1" }
    assert_equal 9, @group.reload.unit_shells.count, "the resubmitted form recorded once"
  end

  test "Confirm without a date re-renders with the error" do
    UpdateSupplierArrangement.new(agency: @agency, actor: @admin, departure: @departure, arrangement: @arrangement,
      attributes: { group_reference: "GRP-9", payee_account_id: @payee.id }, lock_version: @arrangement.lock_version).call
    sign_in_as @admin
    post departure_arrangement_confirmation_path(@departure, @arrangement), params: { confirmed_on: "", lock_version: @arrangement.reload.lock_version }
    assert_response :unprocessable_entity
    assert_select "#form-error-summary", text: /date the supplier confirmed/
    assert @arrangement.reload.draft?
  end

  test "staff without Supplier arrangements can't confirm" do
    sign_in_as agency_users(:harbor_staff)
    post departure_arrangement_confirmation_path(@departure, @arrangement), params: { confirmed_on: "2026-11-01", lock_version: @arrangement.lock_version }
    assert_redirected_to root_path
    assert @arrangement.reload.draft?
  end
end
