require "test_helper"

class M2DepartureIsolationRequestTest < ActionDispatch::IntegrationTest
  setup do
    @primary = M2DepartureScenario.celebrity
    @companion = M2DepartureScenario.isolation_companion(@primary)
  end

  test "foreign departure routes return not found" do
    sign_in_as @primary.directory.actor
    foreign = @companion.departure

    get departure_path(foreign)
    assert_response :not_found
    get edit_departure_path(foreign)
    assert_response :not_found
    patch departure_path(foreign), params: { departure: { name: "Stolen", lock_version: foreign.lock_version } }
    assert_response :not_found
    get departure_activation_path(foreign)
    assert_response :not_found
    post activate_departure_path(foreign), params: { lock_version: foreign.lock_version }
    assert_response :not_found
    get edit_departure_return_to_draft_path(foreign)
    assert_response :not_found
    post departure_return_to_draft_path(foreign), params: { departure: { reason: "no", lock_version: foreign.lock_version } }
    assert_response :not_found
    get new_departure_departed_path(foreign)
    assert_response :not_found
    post departure_departed_path(foreign), params: { departure: { lock_version: foreign.lock_version } }
    assert_response :not_found
    get edit_departure_schedule_correction_path(foreign)
    assert_response :not_found
    get edit_departure_currency_correction_path(foreign)
    assert_response :not_found
    get edit_departure_lifecycle_correction_path(foreign)
    assert_response :not_found
    assert_equal "Celebrity Beyond Isolation", foreign.reload.name
    assert_equal "draft", foreign.status
  end

  test "viewer browses home departures and cannot mutate" do
    sign_in_as @primary.directory.viewer
    get departures_path
    assert_response :success
    assert_includes response.body, @primary.departure.name
    assert_not_includes response.body, @companion.departure.name
    get departure_path(@primary.departure)
    assert_response :success
    post departures_path, params: { departure: { name: "Viewer Leak" } }
    assert_redirected_to root_path
    assert_nil @primary.directory.agency.departures.find_by(name: "Viewer Leak")
  end
end
