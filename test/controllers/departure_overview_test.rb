require "test_helper"

# S-06 and S-07 (UX consolidation audit A3, batch 3): the Departure
# overview sums up bookings, space left, client money, supplier money and
# tasks from the Alpha fixture, each panel only for staff who may see it;
# the Departures list shows each one's bookings, space and money due.
class DepartureOverviewTest < ActionDispatch::IntegrationTest
  setup do
    set_clock Time.utc(2027, 1, 12, 15)
    @agency = agencies(:harbor)
    @admin = agency_users(:harbor_admin)
    @alpha = AlphaFixture.load!(agency: @agency, actor: @admin, bookings: :confirmed)
    @departure = @alpha.departure
  end

  test "the overview sums the Departure up from its records" do
    sign_in_as @admin
    get departure_path(@departure)
    assert_response :success

    assert_select "#summary-bookings" do
      assert_select "dt", text: "Confirmed"
      assert_select "dd", text: "3"
      assert_select "dd", text: "10 travelers"
    end
    assert_select "#summary-space" do
      assert_select "caption", text: "Cabin"
      assert_select "tr", text: /V01\s*7 of 8 left/
      assert_select "tr", text: /I01\s*8 of 8 left/
      assert_select "caption", text: "Nov 5 hotel room"
    end
    assert_select "#summary-client-money" do
      assert_select "dd", text: "$29,280.00"
      assert_select "dd", text: "Next: $500.00 on January 12, 2027"
    end
    assert_select "#summary-supplier-money" do
      assert_select "dd", text: "$2,950.00"
      assert_select "dd", text: "$28,095.00"
      assert_select "dd", text: "$3,829.00"
    end
    assert_select "#summary-tasks" do
      assert_select "p", text: "7 open tasks, 1 overdue."
      assert_select "li", count: DepartureSummary::TASKS_SHOWN
    end
    assert_select "#details h2", text: "Status and details"
  end

  test "client and supplier money are separate panels, and supplier money needs its permission" do
    sign_in_as agency_users(:harbor_baseline_staff)
    get departure_path(@departure)
    assert_response :success
    assert_select "#summary-bookings"
    assert_select "#summary-space"
    assert_select "#summary-client-money"
    assert_select "#summary-supplier-money", count: 0
    assert_select "#summary-tasks"
  end

  test "the Departures list shows bookings, space left by included choice and money due" do
    sign_in_as @admin
    get departures_path
    assert_response :success
    assert_select "tr", text: /Alpha Omega/ do
      assert_select "td", text: /Bookings\s*3/
      assert_select "td", text: /Cabin: 29 of 32 left/
      assert_select "td", text: /Nov 5 hotel room: 4 of 8 left/
      assert_select "td", text: /\$29,280\.00/
    end
  end

  test "a refused operating decision keeps the note and shows the error on the page" do
    sign_in_as @admin
    stale = @departure.lock_version
    decisions = @departure.decisions.count
    @departure.update!(description: "Moved on")
    post departure_decisions_path(@departure), params: { departure_decision: { decision: "proceed", note: "Keep this", lock_version: stale } }
    assert_response :unprocessable_entity
    assert_select "#decision #form-error-summary"
    assert_select "#decision textarea[name='departure_decision[note]']", text: "Keep this"
    assert_select "#decision input[name='departure_decision[lock_version]'][value='#{@departure.reload.lock_version}']"
    assert_equal decisions, @departure.decisions.count
  end

  test "the overview's and the list's query counts don't grow with more bookings" do
    sign_in_as @admin
    path = departure_path(@departure)
    get path
    get departures_path
    overview = select_query_count { get path }
    list = select_query_count { get departures_path }
    2.times { add_booking! }
    get path
    get departures_path
    assert_equal overview, select_query_count { get path }
    assert_equal list, select_query_count { get departures_path }
  end

  test "another agency's Departure is not found" do
    sign_in_as agency_users(:cove_admin)
    get departure_path(@departure)
    assert_response :not_found
  end

  private

  def add_booking!
    client = @alpha.trips.values.first.client
    trip = SaveClientTrip.new(agency: @agency, actor: @admin, attributes: { client_id: client.id, departure_id: @departure.id }).call.record
    booking = CreateClientBooking.new(agency: @agency, actor: @admin, trip:).call.record
    guest = SaveBookingTraveler.new(agency: @agency, actor: @admin, booking:, attributes: { placeholder_label: "Guest 1", traveler_type_id: @agency.traveler_types.find_by!(name: "Adult").id }).call.record
    cabin = @alpha.offering.choices.find_by!(name: "Cabin").options.find_by!(label: "I01")
    SaveChoiceSelection.new(agency: @agency, actor: @admin, booking:, attributes: { offering_option_id: cabin.id, occupant_ids: [ guest.id ] }).call
  end

  def select_query_count
    queries = []
    callback = ->(*, payload) { queries << payload[:sql] unless payload[:name] == "SCHEMA" }
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { yield }
    queries.count { |sql| sql.start_with?("SELECT") }
  end
end
