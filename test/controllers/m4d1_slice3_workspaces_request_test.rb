# frozen_string_literal: true

require "test_helper"

class M4d1Slice3WorkspacesRequestTest < ActionDispatch::IntegrationTest
  setup do
    @agency = agencies(:harbor)
    @staff = agency_users(:harbor_staff)
    @viewer = agency_users(:harbor_viewer)
    @departure = create_capacity_departure(@agency, name: "Hilton stay")
    @contractor = create_capacity_supplier(@agency, "Hilton")
    @setup = CreateHotelStaySetup.new(
      agency: @agency, actor: @staff, departure: @departure, idempotency_key: SecureRandom.uuid,
      arrangement_attributes: { name: "Hilton Waikiki", contracting_supplier_id: @contractor.id },
      item_attributes: { name: "Hilton Waikiki" },
      occurrence_attributes: { name: "Stay", starts_on: "2027-11-02", ends_on: "2027-11-05", time_zone: "America/New_York" }
    ).call
    @arrangement = @setup.record.arrangement
    @item = @setup.record.item
  end

  test "viewer is not found" do
    sign_in_as @viewer
    get departure_arrangement_hotel_path(@departure, @arrangement)
    assert_response :not_found
  end

  test "summary does not include a form until an editor opens" do
    sign_in_as @staff
    get departure_arrangement_hotel_path(@departure, @arrangement)
    assert_response :success
    assert_select "#hotel-workspace form", count: 0
    assert_select "h2", text: "Stay"
    get departure_arrangement_hotel_path(@departure, @arrangement, editor: "component")
    assert_select "form"
  end

  test "an invalid cost keeps the submitted amount and a valid cost redirects" do
    sign_in_as @staff
    version = @arrangement.versions.sole
    post supplier_component_departure_arrangement_hotel_path(@departure, @arrangement), params: {
      editor: "component", idempotency_key: SecureRandom.uuid, arrangement_item_id: @item.id,
      version_lock_version: version.lock_version, label: "", amount: "20.00", shape: "per_person_night"
    }
    assert_response :unprocessable_entity
    assert_select "input[name=amount][value=?]", "20.00"
    assert_select "#form-error-summary"

    post supplier_component_departure_arrangement_hotel_path(@departure, @arrangement), params: {
      editor: "component", idempotency_key: SecureRandom.uuid, arrangement_item_id: @item.id,
      version_lock_version: version.reload.lock_version, label: "Additional adult", amount: "20.00", shape: "per_person_night"
    }
    assert_response :see_other
  end

  test "the dmc table links each family and a failed activity leaves the transfer" do
    sign_in_as @staff
    transfer = CreateTransportationSegment.new(
      agency: @agency, actor: @staff, departure: @departure, arrangement: @arrangement,
      version_lock_version: @arrangement.versions.sole.lock_version, idempotency_key: SecureRandom.uuid,
      seat_count: 15, arrangement_attributes: {}, item_attributes: { name: "Hotel to Port" },
      occurrence_attributes: { name: "Hotel to Port", pickup: "Hotel", dropoff: "Port", starts_on: "2027-11-06", ends_on: "2027-11-06", time_zone: "America/New_York" }
    ).call
    RecordTransportationSupplierComponent.new(
      agency: @agency, actor: @staff, arrangement: @arrangement, idempotency_key: SecureRandom.uuid,
      attributes: {
        arrangement_item_id: transfer.record.item.id, label: "Hotel to Port", amount: "200.00", shape: "per_segment",
        version_lock_version: @arrangement.versions.sole.reload.lock_version
      }
    ).call
    activity = CreateActivityOffering.new(
      agency: @agency, actor: @staff, departure: @departure, template: "meal", arrangement: @arrangement,
      version_lock_version: @arrangement.versions.sole.reload.lock_version, idempotency_key: SecureRandom.uuid,
      arrangement_attributes: {}, item_attributes: { name: "Welcome dinner" },
      occurrence_attributes: { name: "Dinner", starts_on: "2027-10-08", ends_on: "2027-10-08", time_zone: "America/New_York" }
    ).call
    get departure_arrangement_dmc_items_path(@departure, @arrangement)
    assert_response :success
    assert_select "a[href=?]", departure_arrangement_hotel_path(@departure, @arrangement)
    assert_select "a[href=?]", departure_arrangement_transportation_path(@departure, @arrangement)
    assert_select "a[href=?]", departure_arrangement_activities_path(@departure, @arrangement)

    post supplier_component_departure_arrangement_activities_path(@departure, @arrangement), params: {
      editor: "component", idempotency_key: SecureRandom.uuid, arrangement_item_id: activity.record.item.id,
      version_lock_version: @arrangement.versions.sole.reload.lock_version, label: "Dinner", amount: "", shape: "per_person"
    }
    assert_response :unprocessable_entity
    assert_select "input[name=amount][value=?]", ""
    assert_equal 20_000, SupplierCostComponent.joins(supplier_cost_definition: :supplier_cost_source)
      .find_by!(supplier_cost_sources: { arrangement_item_id: transfer.record.item.id }).amount_minor_units
  end
end
