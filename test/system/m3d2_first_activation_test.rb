require "application_system_test_case"

class M3d2FirstActivationTest < ApplicationSystemTestCase
  include CapacityGraphHelper

  setup do
    @agency = agencies(:harbor)
    @staff = agency_users(:harbor_staff)
    @supplier = create_capacity_supplier(@agency, "Activation Browser Supplier")
    @departure = create_capacity_departure(@agency, name: "Browser Activation")
    @departure.update!(
      status: "active", departure_reference: "D-846292",
      first_activated_at: Time.current
    )
    graph = create_capacity_graph(
      agency: @agency, departure: @departure,
      contractor: @supplier, provider: @supplier,
      prefix: "Browser Activation", capacity_management: "unmanaged"
    )
    @arrangement = graph[:arrangement]
    @version = graph[:version]
    source = SupplierCostSource.create!(
      agency: @agency, departure: @departure,
      supplier_arrangement: @arrangement,
      supplier_arrangement_version: @version,
      arrangement_item: graph[:item], charging_supplier: @supplier,
      label: "Entered lodging", position: 1
    )
    SupplierCostDefinition.create!(
      agency: @agency, departure: @departure,
      supplier_arrangement: @arrangement,
      supplier_arrangement_version: @version,
      supplier_cost_source: source, stage: "contracted",
      status: "forecast_ready", mode: "zero_cost",
      zero_cost_reason: "Included", currency: "USD",
      forecast_ready_by: @staff, forecast_ready_at: Time.current,
      readiness_fingerprint: "sha256:system",
      readiness_provenance: "Signed"
    )
  end

  test "staff activates through the compressed checklist" do
    sign_in_from_browser(@staff)
    visit departure_arrangement_path(@departure, @arrangement)
    click_link "Activate arrangement"

    assert_selector "h1.dd-page-title", exact_text: "Activate arrangement"
    assert_text "Ready for activation."
    check "I confirm the entered cost-source list is complete."
    check "I confirm known confirmation-triggered commitments are covered by the listed triggers."
    select "Supplier confirmation", from: "Evidence kind"
    fill_in_html_date "Evidence date", Date.current.iso8601
    fill_in "Channel", with: "Supplier portal"
    fill_in "Safe reference note", with: "Supplier confirmed exact version"
    fill_in "Confirmed without identifier reason", with: "No identifier was issued"
    click_button "Activate arrangement"

    assert_text "Arrangement activated."
    assert_text "Active"
    assert_equal "active", @arrangement.reload.status
  end
end
