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
    within(:xpath, "//article[.//h2[normalize-space()='Client offers (draft)']]") do
      click_link "Add service from Supplier planning"
    end

    assert_selector "h1.dd-page-title", exact_text: "Add service from Supplier planning"
    assert_text "Tentative draft"
    fill_in "Client-facing title", with: "System cabin"
    fill_in "Staff display name", with: "System cabin"
    click_button "Save draft"

    assert_text "Service offer draft saved."
    assert_selector "h1.dd-page-title", exact_text: "System cabin"
    assert_text "There is no Publish action in this slice."
    assert_no_selector :link, exact_text: "Publish"
    assert_no_selector :button, exact_text: "Publish"
    assert_no_text "indicative margin"

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
