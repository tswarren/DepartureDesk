require "application_system_test_case"

class ServiceOffersSystemTest < ApplicationSystemTestCase
  setup do
    @agency = agencies(:harbor)
    @staff = agency_users(:harbor_staff)
    @viewer = agency_users(:harbor_viewer)
    @contractor = create_capacity_supplier(@agency, "System Offer Contractor")
    @departure = create_capacity_departure(@agency, name: "System Offer Departure")
    @graph = create_capacity_graph(
      agency: @agency, departure: @departure, contractor: @contractor, provider: @contractor, prefix: "SystemOffer"
    )
  end

  test "staff creates a source-backed draft from the departure and discards it" do
    sign_in_from_browser(@staff)

    visit departure_path(@departure)
    assert_selector "h1.dd-page-title", exact_text: "System Offer Departure"
    click_link "Client offers"
    click_link "Add service from Supplier planning"

    assert_selector "h1.dd-page-title", exact_text: "Add service from Supplier planning"
    assert_text "Tentative draft"
    fill_in "Client-facing title", with: "System cabin"
    fill_in "Staff display name", with: "System cabin"
    click_button "Save draft"

    assert_text "Service offer draft saved."
    assert_selector "h1.dd-page-title", exact_text: "System cabin"
    assert_text "Publish freezes this standalone version"
    assert_button "Publish"
    assert_no_text "indicative margin"
    assert_text "Client price"
    fill_in "Amount (USD)", with: "125.00"
    click_button "Save Client price"
    assert_text "Client price saved."
    assert_text "$125.00"

    find("summary", text: "Advanced price details").click
    assert_button "Add component"
    4.times { click_button "Add component" }
    within(:xpath, "//form[.//input[@value='Replace advanced price' or @value='Save advanced Client price']]") do
      fill_in "price_components_0_label", with: "First"
      select "Occupancy positions", from: "price_components_0_quantity_basis"
      fill_in "price_components_0_amount", with: "210.00"
      fill_in "price_components_0_occupancy", with: "first"
      fill_in "price_components_1_label", with: "Second"
      select "Occupancy positions", from: "price_components_1_quantity_basis"
      fill_in "price_components_1_amount", with: "210.00"
      fill_in "price_components_1_occupancy", with: "second"
      fill_in "price_components_2_label", with: "Additional"
      select "Occupancy positions", from: "price_components_2_quantity_basis"
      fill_in "price_components_2_amount", with: "55.00"
      fill_in "price_components_2_occupancy", with: "additional"
      fill_in "price_components_3_label", with: "Single"
      select "Occupancy positions", from: "price_components_3_quantity_basis"
      fill_in "price_components_3_amount", with: "320.00"
      fill_in "price_components_3_occupancy", with: "single"
      fill_in "price_components_4_label", with: "Port tax"
      select "Tax fee", from: "price_components_4_client_role"
      select "Fixed", from: "price_components_4_calculation_kind"
      fill_in "price_components_4_amount", with: "12.00"
      click_button "Replace advanced price"
    end
    assert_text "Client price updated."
    assert_text "Port tax"

    click_link "Edit draft"
    assert_text "Reselect the current governing activated source for each binding. Keep this Client text."
    click_link "Cancel"

    click_link "Discard draft"
    assert_selector "h1.dd-page-title", exact_text: "Discard draft"
    fill_in "Reason", with: "Changed the sales plan"
    click_button "Discard draft"

    assert_text "Service offer draft discarded."
    assert_selector "h1.dd-page-title", exact_text: "System Offer Departure"
  end

  test "viewer cannot see unpublished offer actions" do
    CreateServiceOfferWithExplicitBasis.new(
      agency: @agency, actor: @staff, departure: @departure, idempotency_key: SecureRandom.uuid,
      attributes: { client_title: "Hidden system draft", fulfillment_basis: "on_request" }
    ).call

    sign_in_from_browser(@viewer)
    visit departure_path(@departure)
    assert_selector "h1.dd-page-title", exact_text: "System Offer Departure"
    assert_no_text "Client offers (draft)"
    assert_no_text "Add service from Supplier planning"
    assert_no_text "Add explicit-basis service"
  end
end
