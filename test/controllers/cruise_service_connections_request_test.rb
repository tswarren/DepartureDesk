# frozen_string_literal: true

require "test_helper"

class CruiseServiceConnectionsRequestTest < ActionDispatch::IntegrationTest
  setup do
    @agency = agencies(:harbor)
    @staff = agency_users(:harbor_staff)
    @viewer = agency_users(:harbor_viewer)
    @departure = create_capacity_departure(@agency, name: "Smith Family Cruise")
    @contractor = create_capacity_supplier(@agency, "Celebrity Cruises")
    @provider = create_capacity_supplier(@agency, "Celebrity Ship Ops")
    @contact = @contractor.contacts.create!(
      agency: @agency, first_name: "Group", last_name: "Desk", status: "active"
    )
    sailing = CreateCruiseSailingSetup.new(
      agency: @agency, actor: @staff, departure: @departure,
      arrangement_attributes: {
        name: "Celebrity group agreement",
        contracting_supplier_id: @contractor.id,
        supplier_contact_id: @contact.id
      },
      item_attributes: { name: "Celebrity Beyond", default_service_provider_id: @provider.id },
      occurrence_attributes: {
        name: "Western Caribbean", starts_on: "2027-11-06", ends_on: "2027-11-13", time_zone: "America/New_York"
      },
      idempotency_key: SecureRandom.uuid
    ).call
    @arrangement = sailing.record.arrangement
    @item = sailing.record.item
    @version = @arrangement.versions.sole
    cabin = CreateCruiseCabinCategorySetup.new(
      agency: @agency, actor: @staff, arrangement: @arrangement,
      resource_attributes: { name: "Prime Oceanview", supplier_code: "O1", maximum_occupancy: 3 },
      pool_attributes: { inventory_mode: "block", proposed_opening_quantity: 8 },
      version_lock_version: @version.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call
    @resource = cabin.record.resource
    @version.reload
  end

  test "viewer cannot open the cruise service connection" do
    sign_in_as @viewer
    get departure_arrangement_cruise_service_connection_path(@departure, @arrangement)
    assert_response :not_found
  end

  test "staff sees the summary and a failed save keeps the entered title" do
    sign_in_as @staff
    get departure_arrangement_cruise_service_connection_path(@departure, @arrangement)
    assert_response :success
    assert_match "Not connected", response.body
    assert_no_match "comes later", response.body

    get departure_arrangement_cruise_service_connection_path(@departure, @arrangement, editor: "connect", sailing: "draft")
    assert_response :success
    assert_match "Connect Cruise service", response.body

    post departure_arrangement_cruise_service_connection_path(@departure, @arrangement), params: {
      mode: "new",
      title: "Kept title",
      sailing: "draft",
      use_tentative_draft: "1",
      supplier_arrangement_version_id: @version.id,
      arrangement_lock_version: @version.lock_version,
      idempotency_key: SecureRandom.uuid
    }
    assert_response :unprocessable_entity
    assert_match "Connect Cruise service", response.body
    assert_match "Kept title", response.body
  end

  test "creating a service redirects to the summary without the editor query" do
    sign_in_as @staff
    post departure_arrangement_cruise_service_connection_path(@departure, @arrangement), params: {
      mode: "new",
      title: "Celebrity Beyond sailing",
      sailing: "draft",
      use_tentative_draft: "1",
      supplier_arrangement_version_id: @version.id,
      arrangement_lock_version: @version.lock_version,
      supplier_resource_ids: [ @resource.id ],
      idempotency_key: SecureRandom.uuid
    }
    assert_response :see_other
    assert_redirected_to departure_arrangement_cruise_service_connection_path(@departure, @arrangement)
    follow_redirect!
    assert_match "Connected", response.body
    assert_match "Ready for category pricing", response.body
    assert_no_match "cruise_cabin:", response.body

    offer = ServiceOffer.find_by!(name: "Celebrity Beyond sailing")
    get departure_service_offer_path(@departure, offer)
    assert_response :success
    assert_match "Open Cruise service connection", response.body
    assert_no_match "Save choices", response.body
  end

  test "decide later redirects to a summary that can be resumed" do
    sign_in_as @staff
    post departure_arrangement_cruise_service_connection_path(@departure, @arrangement), params: {
      mode: "later",
      title: "Smith sailing",
      sailing: "draft",
      use_tentative_draft: "1",
      supplier_arrangement_version_id: @version.id,
      arrangement_lock_version: @version.lock_version,
      idempotency_key: SecureRandom.uuid
    }
    assert_response :see_other
    follow_redirect!
    assert_match "Decide later", response.body
    assert_match "Smith sailing", response.body
  end
end
