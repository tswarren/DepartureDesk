require "test_helper"

# S-25 roster and S-17 inventory: query counts stay flat as bookings grow.
class BookingQueryCountTest < ActionDispatch::IntegrationTest
  setup do
    set_clock Time.utc(2027, 1, 12, 15)
    @agency = agencies(:harbor)
    @admin = agency_users(:harbor_admin)
    @alpha = AlphaFixture.load!(agency: @agency, actor: @admin, bookings: :held)
    sign_in_as @admin
  end

  test "the roster and the inventory page don't grow with more bookings" do
    roster = departure_bookings_path(@alpha.departure)
    inventory = departure_inventory_path(@alpha.departure)
    get roster
    get inventory
    roster_three = select_query_count { get roster }
    inventory_three = select_query_count { get inventory }

    3.times { add_booking! }
    get roster
    get inventory
    assert_equal roster_three, select_query_count { get roster }
    assert_equal inventory_three, select_query_count { get inventory }
  end

  test "the roster, the Resellers list and a reseller's page don't grow with more resellers and bookings (S-04, S-25)" do
    reseller = SaveReseller.new(agency: @agency, actor: @admin, attributes: { name: "Coral Coast Travel" }).call.record
    PublishOffering.new(agency: @agency, actor: @admin, offering: @alpha.offering, reseller:).call
    assign = ->(booking) { AssignClientBooking.new(agency: @agency, actor: @admin, booking:, reseller:).call }
    assign.(@alpha.bookings.values.first)
    pages = [ departure_bookings_path(@alpha.departure), resellers_path, reseller_path(reseller) ]
    pages.each { |page| get page }
    before = pages.map { |page| select_query_count { get page } }

    2.times { |index| SaveReseller.new(agency: @agency, actor: @admin, attributes: { name: "Reseller #{index}" }).call }
    2.times { assign.(add_booking!) }
    pages.each { |page| get page }
    assert_equal before, pages.map { |page| select_query_count { get page } }
  end

  private

  def add_booking!
    client = @alpha.trips.values.first.client
    trip = SaveClientTrip.new(agency: @agency, actor: @admin, attributes: { client_id: client.id, departure_id: @alpha.departure.id }).call.record
    booking = CreateClientBooking.new(agency: @agency, actor: @admin, trip:).call.record
    guest = SaveBookingTraveler.new(agency: @agency, actor: @admin, booking:, attributes: { placeholder_label: "Guest 1", traveler_type_id: @agency.traveler_types.find_by!(name: "Adult").id }).call.record
    cabin = @alpha.offering.choices.find_by!(name: "Cabin").options.find_by!(label: "I01")
    tour = @alpha.offering.choices.find_by!(name: "Private Miami tour").options.sole
    [ cabin, tour ].each { |option| SaveChoiceSelection.new(agency: @agency, actor: @admin, booking:, attributes: { offering_option_id: option.id, occupant_ids: [ guest.id ] }).call }
    HoldBookingSpace.new(agency: @agency, actor: @admin, booking:).call
    booking
  end

  def select_query_count
    queries = []
    callback = ->(*, payload) { queries << payload[:sql] unless payload[:name] == "SCHEMA" }
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { yield }
    queries.count { |sql| sql.start_with?("SELECT") }
  end
end
