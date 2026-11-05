require "test_helper"

class DepartureDepartedLifecycleControllerTest < ActionDispatch::IntegrationTest
  setup do
    @agency = agencies(:harbor)
    @admin = agency_users(:harbor_admin)
    @baseline_staff = agency_users(:harbor_baseline_staff)
    @office = offices(:harbor_main)
  end

  test "staff can mark an eligible departure departed" do
    sign_in_as agency_users(:harbor_staff)
    departure = eligible_active("Request Depart")
    get new_departure_departed_path(departure)
    assert_response :success
    post departure_departed_path(departure), params: { departure: { lock_version: departure.lock_version } }
    assert_redirected_to departure_path(departure)
    assert_equal "departed", departure.reload.summary_label
    assert_equal "agency_user", AuditEvent.find_by!(action: "departure.departed", subject_id: departure.id).actor_kind
  end

  test "a departed departure is read-only and offers no edit or status actions (DEP-43)" do
    departure = departed_departure
    sign_in_as @admin

    get departure_path(departure)
    assert_response :success
    assert_select "a", text: "Edit departure", count: 0
    assert_select "a", text: "Return to Draft", count: 0

    get edit_departure_path(departure)
    assert_redirected_to departure_path(departure)
    patch departure_path(departure), params: { departure: { name: "Renamed", lock_version: departure.lock_version } }
    assert_redirected_to departure_path(departure)
    assert_not_equal "Renamed", departure.reload.name

    error = assert_raises(AgencyCommand::Error) do
      UpdateDeparture.new(agency: @agency, actor: @admin, departure:, attributes: { name: "Renamed" }, lock_version: departure.lock_version).call
    end
    assert_equal :invalid_state, error.code
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
        operating_currency: "USD"
      }
    ).call.record
    MarkDepartureReadyToSell.new(
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
    assert_response :success
    assert_select "a", text: "Mark departed", count: 0

    past = eligible_active("Past Show")
    get departure_path(past)
    assert_select "a", text: "Mark departed"
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
        operating_currency: "USD"
      }
    ).call.record
    MarkDepartureReadyToSell.new(agency: @agency, actor: @admin, departure:, lock_version: departure.lock_version).call.record
  end

  def departed_departure
    departure = eligible_active("Departed Lock")
    MarkDepartureDeparted.new(
      agency: @agency, departure:, actor_kind: :agency_user, actor: @admin, lock_version: departure.lock_version
    ).call.record
  end
end
