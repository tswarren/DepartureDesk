require "test_helper"

class DepartureDepartedLifecycleControllerTest < ActionDispatch::IntegrationTest
  setup do
    @agency = agencies(:harbor)
    @admin = agency_users(:harbor_admin)
    @viewer = agency_users(:harbor_viewer)
    @office = offices(:harbor_main)
  end

  test "staff can mark an eligible departure departed" do
    sign_in_as agency_users(:harbor_staff)
    departure = eligible_active("Request Depart")
    get new_departure_departed_path(departure)
    assert_response :success
    post departure_departed_path(departure), params: { departure: { lock_version: departure.lock_version } }
    assert_redirected_to departure_path(departure)
    assert_equal "departed", departure.reload.status
    assert_equal "agency_user", AuditEvent.find_by!(action: "departure.departed", subject_id: departure.id).actor_kind
  end

  test "departed corrections preserve invalid values and reject viewers" do
    departure = eligible_active("Request Correct")
    MarkDepartureDeparted.new(
      agency: @agency, departure:, actor_kind: :agency_user, actor: @admin, lock_version: departure.lock_version
    ).call
    sign_in_as @admin
    get edit_departure_schedule_correction_path(departure)
    assert_response :success
    post departure_schedule_correction_path(departure), params: {
      departure: {
        starts_on: "",
        ends_on: "",
        time_zone: "",
        reason: "fix",
        lock_version: departure.reload.lock_version
      }
    }
    assert_response :unprocessable_entity
    assert_select "#form-error-summary"

    sign_in_as @viewer
    get new_departure_departed_path(departure)
    assert_redirected_to root_path
    post departure_currency_correction_path(departure), params: {
      departure: { operating_currency: "EUR", reason: "nope", lock_version: departure.lock_version }
    }
    assert_redirected_to root_path
  end

  test "cross-agency departed routes are not found" do
    other = CreateDeparture.new(
      agency: agencies(:cove),
      actor: agency_users(:cove_admin),
      attributes: {
        name: "Cove Active",
        starts_on: "2026-06-01",
        ends_on: "2026-06-08",
        time_zone: "UTC",
        operating_currency: "USD",
        responsible_office_id: offices(:cove_main).id,
        responsible_agency_user_id: agency_users(:cove_admin).id
      }
    ).call.record
    ActivateDeparture.new(
      agency: agencies(:cove), actor: agency_users(:cove_admin), departure: other, lock_version: other.lock_version
    ).call
    sign_in_as @admin
    get new_departure_departed_path(other)
    assert_response :not_found
    post departure_departed_path(other), params: { departure: { lock_version: other.lock_version } }
    assert_response :not_found
  end

  test "show offers mark departed only when eligible" do
    sign_in_as @admin
    future = eligible_active("Future Show", starts_on: Date.new(2099, 1, 1), ends_on: Date.new(2099, 1, 8))
    get departure_path(future)
    assert_redirected_to departure_builder_path(future)
    follow_redirect!
    assert_response :success
    assert_select "a", text: "Mark departed", count: 0

    past = eligible_active("Past Show")
    get departure_path(past)
    assert_redirected_to departure_builder_path(past)
    follow_redirect!
    assert_select "a", text: "Mark departed"
  end

  test "currency and lifecycle corrections succeed for staff" do
    departure = eligible_active("Request Lifecycle")
    MarkDepartureDeparted.new(
      agency: @agency, departure:, actor_kind: :agency_user, actor: @admin, lock_version: departure.lock_version
    ).call
    CorrectDepartureSchedule.new(
      agency: @agency, actor: @admin, departure:,
      starts_on: Date.new(2099, 6, 1), ends_on: Date.new(2099, 6, 8), time_zone: "UTC",
      reason: "Postponed", lock_version: departure.reload.lock_version
    ).call
    sign_in_as @admin
    post departure_currency_correction_path(departure), params: {
      departure: { operating_currency: "EUR", reason: "Quoted in euro", lock_version: departure.reload.lock_version }
    }
    assert_redirected_to departure_path(departure)
    assert_equal "EUR", departure.reload.operating_currency

    post departure_lifecycle_correction_path(departure), params: {
      departure: { reason: "Marked too soon", lock_version: departure.lock_version }
    }
    assert_redirected_to departure_path(departure)
    assert_equal "active", departure.reload.status
    assert_nil departure.departed_at
  end

  private

  def eligible_active(name, starts_on: Date.new(2026, 6, 1), ends_on: Date.new(2026, 6, 8))
    departure = CreateDeparture.new(
      agency: @agency,
      actor: @admin,
      attributes: {
        name:,
        starts_on:,
        ends_on:,
        time_zone: "America/New_York",
        operating_currency: "USD",
        responsible_office_id: @office.id,
        responsible_agency_user_id: @admin.id
      }
    ).call.record
    ActivateDeparture.new(agency: @agency, actor: @admin, departure:, lock_version: departure.lock_version).call.record
  end
end
