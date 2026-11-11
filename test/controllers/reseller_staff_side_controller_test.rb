require "test_helper"

# Slice 1 step 9a screens: S-04 Resellers, S-10 reseller channels on the
# Package tab, and the owner and seller of record on the roster (S-25) and
# the booking Summary (S-26). ACC-13, ACC-18, DEP-07 to DEP-09, FIN-05.
class ResellerStaffSideControllerTest < ActionDispatch::IntegrationTest
  setup do
    set_clock Time.utc(2027, 1, 10, 15)
    @agency = agencies(:harbor)
    @admin = agency_users(:harbor_admin)
    @staff = agency_users(:harbor_staff)
    @baseline = agency_users(:harbor_baseline_staff)
    @alpha = AlphaFixture.load!(agency: @agency, actor: @admin, bookings: :confirmed)
    set_clock Time.utc(2027, 2, 3, 15)
    @booking = @alpha.bookings.fetch("BK-105")
  end

  test "an Agency Admin authorizes and edits a reseller; others are refused and another agency's is not found (ACC-13)" do
    sign_in_as @admin
    get resellers_path
    assert_select "h2", text: "No resellers"
    assert_select "nav[aria-label='Primary navigation'] a, .dd-sidebar-footer a", text: "Resellers"

    post resellers_path, params: { reseller: { name: " ", direct_contact_allowed: "1" } }
    assert_response :unprocessable_entity
    assert_select "input#reseller_name[aria-invalid=true]"

    post resellers_path, params: { reseller: { name: "Coral Coast Travel", direct_contact_allowed: "1" } }
    reseller = @agency.resellers.find_by!(name: "Coral Coast Travel")
    assert_redirected_to reseller_path(reseller)
    follow_redirect!
    assert_select "h1", text: "Coral Coast Travel"
    assert_select "dd", text: /may send documents directly/
    assert_select "p", text: /Nothing is published to Coral Coast Travel/

    patch reseller_path(reseller), params: { reseller: { name: "Coral Coast Travel", direct_contact_allowed: "0", lock_version: reseller.lock_version } }
    assert_not reseller.reload.direct_contact_allowed
    get resellers_path
    assert_select "td", text: /Through the reseller only/

    cove = Reseller.create!(agency: agencies(:cove), name: "Cove Partner")
    get reseller_path(cove)
    assert_response :not_found

    sign_in_as @staff
    get resellers_path
    assert_redirected_to root_path
    get root_path
    assert_select ".dd-sidebar a", text: "Resellers", count: 0
  end

  test "the Package tab publishes to and withdraws from each reseller's channel; a draft Departure can't publish (S-10, DEP-07, DEP-09)" do
    reseller = SaveReseller.new(agency: @agency, actor: @admin, attributes: { name: "Coral Coast Travel" }).call.record
    sign_in_as @staff
    get departure_offerings_path(@alpha.departure)
    assert_select "#channels-#{@alpha.offering.id} li", text: /Coral Coast Travel\s+Not published/
    assert_select "button[aria-label='Publish #{@alpha.offering.name} to Coral Coast Travel']"

    post departure_offering_publications_path(@alpha.departure, @alpha.offering), params: { reseller_id: reseller.id }
    assert_redirected_to departure_offerings_path(@alpha.departure, anchor: "channels-#{@alpha.offering.id}")
    follow_redirect!
    assert_select "#channels-#{@alpha.offering.id} li", text: /Coral Coast Travel\s+Published.*Since February 0?3, 2027/m

    publication = @alpha.offering.publications.sole
    delete departure_offering_publication_path(@alpha.departure, @alpha.offering, publication)
    assert_not publication.reload.open?

    departure = @alpha.departure.reload
    ReturnDepartureToDraft.new(agency: @agency, actor: @staff, departure:, reason: nil, lock_version: departure.lock_version).call
    get departure_offerings_path(@alpha.departure)
    assert_select "p", text: /This Departure is a draft, so its package can't be published/
    assert_select "button", text: "Publish", count: 0
    post departure_offering_publications_path(@alpha.departure, @alpha.offering), params: { reseller_id: reseller.id }
    follow_redirect!
    assert_select "[role=alert], .dd-alert, .dd-flash", text: /is a draft. Mark it Ready to sell/

    sign_in_as @baseline
    get departure_offerings_path(@alpha.departure)
    assert_select "#channels-#{@alpha.offering.id} li", text: /Coral Coast Travel/
    assert_select "#channels-#{@alpha.offering.id} button", count: 0
    post departure_offering_publications_path(@alpha.departure, @alpha.offering), params: { reseller_id: reseller.id }
    assert_redirected_to root_path
    assert_empty @alpha.offering.publications.open
  end

  test "the roster and Summary show the owner and seller of record; Departure management assigns them (ACC-18, FIN-05)" do
    reseller = SaveReseller.new(agency: @agency, actor: @admin, attributes: { name: "Coral Coast Travel" }).call.record
    sign_in_as @staff
    get client_booking_path(@booking)
    assert_select "#summary-sales dd", text: "Agency", count: 2
    assert_select "#summary-sales summary", text: "Change the owner"
    assert_select "#summary-sales summary", text: "Change the seller of record", count: 0, message: "fixed once confirmed"

    patch client_booking_assignment_path(@booking), params: { reseller_id: reseller.id, lock_version: @booking.lock_version }
    assert_redirected_to client_booking_path(@booking, step: "summary", anchor: "summary-sales")
    follow_redirect!
    assert_select "#summary-sales div", text: /Owner\s*Coral Coast Travel/
    assert_select "#summary-sales div", text: /Seller of record\s*Agency/

    get departure_bookings_path(@alpha.departure)
    assert_select "tr", text: /#{@booking.booking_reference}.*Owner Coral Coast Travel/m

    draft = CreateClientBooking.new(agency: @agency, actor: @baseline, trip: @booking.client_trip).call.record
    patch client_booking_seller_of_record_path(draft), params: { reseller_id: reseller.id, lock_version: draft.lock_version }
    assert_equal reseller, draft.reload.seller_reseller
    patch client_booking_seller_of_record_path(@booking), params: { reseller_id: reseller.id, lock_version: @booking.reload.lock_version }
    follow_redirect!
    assert_select "[role=alert], .dd-alert, .dd-flash", text: /fixed once a booking is confirmed/

    sign_in_as @baseline
    get client_booking_path(@booking)
    assert_select "#summary-sales div", text: /Owner\s*Coral Coast Travel/
    assert_select "#summary-sales form", count: 0
    patch client_booking_assignment_path(@booking), params: { reseller_id: "", lock_version: @booking.reload.lock_version }
    assert_redirected_to root_path
    assert_equal reseller, @booking.reload.owner_reseller

    sign_in_as @staff
    patch client_booking_assignment_path(@booking), params: { reseller_id: Reseller.create!(agency: agencies(:cove), name: "Cove Partner").id }
    assert_response :not_found
  end
end
