# frozen_string_literal: true

require "test_helper"

class HotelReviewsRequestTest < ActionDispatch::IntegrationTest
  setup do
    @agency = agencies(:harbor)
    @staff = agency_users(:harbor_staff)
    @viewer = agency_users(:harbor_viewer)
    @contractor = create_capacity_supplier(@agency, "Hilton Fort Lauderdale Marina")
    @departure = create_capacity_departure(@agency, name: "Smith Family Reunion")
    @departure.update!(
      status: "active",
      departure_reference: "D-#{SecureRandom.random_number(900000) + 100000}",
      first_activated_at: Time.current
    )
    @graph = create_capacity_graph(
      agency: @agency, departure: @departure, contractor: @contractor,
      provider: @contractor, prefix: "Hilton", category: "lodging"
    )
    @arrangement = @graph[:arrangement]
    @item = @graph[:item]
  end

  test "a viewer can read the review and cannot confirm it" do
    sign_in_as @viewer

    get item_hotel_review_departure_arrangement_hotel_path(@departure, @arrangement, @item)
    assert_response :success
    assert_select "h2", text: "Stay"
    assert_select "h2", text: "Supplier confirmation"
    assert_select "button", text: "Confirm Supplier agreement", count: 0
    assert_select "button", text: "Activate arrangement", count: 0

    post item_hotel_review_confirmation_departure_arrangement_hotel_path(@departure, @arrangement, @item),
      params: { idempotency_key: SecureRandom.uuid }
    assert_response :not_found
  end

  test "another agency cannot open the review" do
    sign_in_as agency_users(:cove_admin)

    get item_hotel_review_departure_arrangement_hotel_path(@departure, @arrangement, @item)
    assert_response :not_found
  end

  test "staff see blockers as links and no rooming list as none recorded" do
    sign_in_as @staff

    get item_hotel_review_departure_arrangement_hotel_path(@departure, @arrangement, @item)
    assert_response :success
    assert_select "#hotel-review-deadlines", text: /No rooming list recorded/
    assert_select "#hotel-review-blockers a", minimum: 1
    assert_no_match(/Reviewed — none/, response.body)
  end
end
