require "test_helper"

class DeparturesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @agency = agencies(:harbor)
    @admin = agency_users(:harbor_admin)
    @viewer = agency_users(:harbor_viewer)
    @office = offices(:harbor_main)
  end

  test "admin creates a draft and preserves invalid values" do
    sign_in_as @admin
    patch current_office_path, params: { office_id: offices(:harbor_west).id }

    get new_departure_path
    assert_response :success
    assert_select "select[name='departure[time_zone]'] option[selected][value=?]", @agency.default_timezone
    assert_select "select[name='departure[time_zone]'] option[selected][value=?]", offices(:harbor_west).default_timezone, count: 0
    assert_select "input[name='departure[operating_currency]'][value=?]", @agency.default_currency

    assert_difference -> { @agency.departures.count }, 1 do
      post departures_path, params: {
        departure: {
          name: "Harbor Week",
          description: "",
          starts_on: "2026-09-01",
          ends_on: "2026-09-08",
          time_zone: "America/New_York",
          operating_currency: "USD",
          responsible_office_id: @office.id,
          responsible_agency_user_id: @admin.id
        }
      }
    end
    departure = @agency.departures.find_by!(name: "Harbor Week")
    assert_redirected_to departure_path(departure)
    assert_equal "draft", departure.status

    post departures_path, params: { departure: { name: "", time_zone: "America/Chicago" } }
    assert_response :unprocessable_entity
    assert_select "#form-error-summary"
    assert_select "select[name='departure[time_zone]'] option[selected][value=?]", "America/Chicago"
  end

  test "activation readiness lists missing requirements then activates" do
    sign_in_as @admin
    incomplete = CreateDeparture.new(agency: @agency, actor: @admin, attributes: { name: "Needs Dates" }).call.record

    get departure_activation_path(incomplete)
    assert_response :success
    assert_match "Enter a start date and an end date", response.body
    assert_select "input[type=submit][value='Activate departure']", count: 0

    context = CreateDeparture.new(agency: @agency, actor: @admin, attributes: { name: "Needs Context" }).call.record
    Departure.where(id: context.id).update_all(time_zone: "Not/AZone", operating_currency: nil)
    get departure_activation_path(context)
    assert_response :success
    assert_match "Enter a recognized time zone", response.body
    assert_match "Enter a supported operating currency", response.body

    complete = CreateDeparture.new(
      agency: @agency,
      actor: @admin,
      attributes: {
        name: "Ready to Sail",
        starts_on: "2026-10-01",
        ends_on: "2026-10-08",
        time_zone: "America/New_York",
        operating_currency: "USD",
        responsible_office_id: @office.id,
        responsible_agency_user_id: @admin.id
      }
    ).call.record
    get departure_activation_path(complete)
    assert_response :success
    post activate_departure_path(complete), params: { lock_version: complete.lock_version }
    assert_redirected_to departure_path(complete)
    assert_equal "active", complete.reload.status
    assert_equal "D-000001", complete.departure_reference
  end

  test "viewer can browse but cannot mutate or open editors" do
    departure = CreateDeparture.new(agency: @agency, actor: @admin, attributes: { name: "Viewer Draft" }).call.record
    sign_in_as @viewer

    get departures_path
    assert_response :success
    assert_match "Viewer Draft", response.body
    assert_select "a", text: "New Departure", count: 0

    get departure_path(departure)
    assert_response :success
    assert_select "a", text: "Edit departure", count: 0

    get new_departure_path
    assert_redirected_to root_path
    post departures_path, params: { departure: { name: "Hijack" } }
    assert_redirected_to root_path
    assert_nil @agency.departures.find_by(name: "Hijack")
  end

  test "cross-agency departure ids are not found" do
    other = CreateDeparture.new(
      agency: agencies(:cove),
      actor: agency_users(:cove_admin),
      attributes: { name: "Cove Draft" }
    ).call.record
    sign_in_as @admin

    get departure_path(other)
    assert_response :not_found
    patch departure_path(other), params: { departure: { name: "Stolen", lock_version: other.lock_version } }
    assert_response :not_found
    assert_equal "Cove Draft", other.reload.name
  end

  test "staff can return an active departure to draft" do
    sign_in_as agency_users(:harbor_staff)
    departure = CreateDeparture.new(
      agency: @agency,
      actor: @admin,
      attributes: {
        name: "Returnable",
        starts_on: "2026-11-01",
        ends_on: "2026-11-08",
        time_zone: "America/New_York",
        operating_currency: "USD",
        responsible_office_id: @office.id,
        responsible_agency_user_id: @admin.id
      }
    ).call.record
    ActivateDeparture.new(agency: @agency, actor: @admin, departure:, lock_version: departure.lock_version).call

    get edit_departure_return_to_draft_path(departure)
    assert_response :success
    post departure_return_to_draft_path(departure), params: {
      departure: { reason: "Need a later sailing", lock_version: departure.reload.lock_version }
    }
    assert_redirected_to departure_path(departure)
    assert_equal "draft", departure.reload.status
    assert_equal "D-000001", departure.departure_reference
  end

  test "clearing required fields on an active departure preserves the form" do
    sign_in_as @admin
    departure = CreateDeparture.new(
      agency: @agency,
      actor: @admin,
      attributes: {
        name: "Active Guard",
        starts_on: "2026-10-01",
        ends_on: "2026-10-08",
        time_zone: "America/New_York",
        operating_currency: "USD",
        responsible_office_id: @office.id,
        responsible_agency_user_id: @admin.id
      }
    ).call.record
    ActivateDeparture.new(agency: @agency, actor: @admin, departure:, lock_version: departure.lock_version).call
    departure.reload

    {
      starts_on: "",
      ends_on: "",
      time_zone: "",
      operating_currency: ""
    }.each do |field, value|
      patch departure_path(departure), params: {
        departure: {
          name: departure.name,
          description: departure.description,
          starts_on: departure.starts_on,
          ends_on: departure.ends_on,
          time_zone: departure.time_zone,
          operating_currency: departure.operating_currency,
          lock_version: departure.lock_version,
          field => value
        }
      }
      assert_response :unprocessable_entity, "clearing #{field}"
      assert_select "#form-error-summary"
      departure.reload
      assert_equal Date.new(2026, 10, 1), departure.starts_on
      assert_equal Date.new(2026, 10, 8), departure.ends_on
      assert_equal "America/New_York", departure.time_zone
      assert_equal "USD", departure.operating_currency
    end
  end
end
