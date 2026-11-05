require "test_helper"

class DepartureDecisionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @departure = CreateDeparture.new(agency: agencies(:harbor), actor: agency_users(:harbor_admin), attributes: { name: "Decide Route" }).call.record
  end

  test "staff with departure management record Proceed from the Departure page" do
    sign_in_as agency_users(:harbor_staff)
    get departure_path(@departure)
    assert_select "#decision input[type=submit][value='Record Proceed']"

    post departure_decisions_path(@departure), params: { departure_decision: { decision: "proceed", note: "Go", lock_version: @departure.lock_version } }
    assert_redirected_to departure_path(@departure, anchor: "decision")
    follow_redirect!
    assert_select "#decision td", text: "Go"
    assert @departure.reload.decision_proceed?
  end

  test "staff without departure management see the decision but cannot record one" do
    sign_in_as agency_users(:harbor_baseline_staff)
    get departure_path(@departure)
    assert_select "#decision", text: /Undecided/
    assert_select "#decision form", count: 0

    post departure_decisions_path(@departure), params: { departure_decision: { decision: "proceed", lock_version: @departure.lock_version } }
    assert_redirected_to root_path
    assert @departure.reload.decision_undecided?
  end

  test "another agency's Departure is not found" do
    sign_in_as agency_users(:cove_admin)
    post departure_decisions_path(@departure), params: { departure_decision: { decision: "proceed", lock_version: @departure.lock_version } }
    assert_response :not_found
  end
end
