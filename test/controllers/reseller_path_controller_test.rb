require "test_helper"

# Slice 1 step 9b screens: R-01 to R-03, the guards between the staff and
# reseller areas, reseller-user invitations on S-04, and the client
# directory's "Created by a reseller" filter (ACC-13, ACC-14, ACC-15,
# ACC-31, CLT-25, CMN-19, CMN-52; step 9 plan, questions 3, 7, 8 and 10).
class ResellerPathControllerTest < ActionDispatch::IntegrationTest
  COST_WORDS = /supplier cost|commission|margin|rate table|cost line/i

  setup do
    set_clock Time.utc(2027, 1, 10, 15)
    @agency = agencies(:harbor)
    @admin = agency_users(:harbor_admin)
    @staff = agency_users(:harbor_staff)
    @baseline = agency_users(:harbor_baseline_staff)
    @alpha = AlphaFixture.load!(agency: @agency, actor: @admin, bookings: :held)
    @dana = @alpha.reseller_user
    @booking = @alpha.bookings.fetch("BK-105")
  end

  test "a reseller session is kept to its area, and a staff session out of it (question 8)" do
    sign_in_as @dana
    get root_path
    assert_redirected_to reseller_root_path
    assert_nil flash[:alert]
    [ tasks_path, clients_path, departures_path, departure_path(@alpha.departure), departure_bookings_path(@alpha.departure),
      departure_offerings_path(@alpha.departure), client_booking_path(@booking), client_trip_path(@booking.client_trip),
      new_client_trip_payment_path(@booking.client_trip), suppliers_path, resellers_path, administration_agency_path, edit_current_office_path ].each do |path|
      get path
      assert_redirected_to reseller_root_path, path
    end
    post client_trip_payments_path(@booking.client_trip), params: { client_payment: { amount: "100" } }
    assert_redirected_to reseller_root_path
    assert_empty @booking.client_trip.client_payments
    patch client_booking_assignment_path(@booking), params: { reseller_id: "" }
    assert_redirected_to reseller_root_path
    assert_equal @alpha.reseller, @booking.reload.owner_reseller
    get edit_account_password_path
    assert_response :success

    sign_in_as @staff
    [ reseller_root_path, reseller_offer_path(@alpha.offering), reseller_client_booking_path(@booking) ].each do |path|
      get path
      assert_redirected_to root_path, path
    end
  end

  test "R-01 shows the published offer and the reseller's bookings, and R-02 the client prices and places left, never cost (ACC-14, ACC-31)" do
    sign_in_as @dana
    get reseller_root_path
    assert_response :success
    assert_select "h1", text: "Offers and bookings"
    assert_select "a", text: @alpha.offering.name
    assert_select "tr", text: /#{@booking.booking_reference}.*Mateo Rivera.*Draft.*Held until/m
    assert_select "tr", text: /#{@alpha.bookings.fetch("BK-101").booking_reference}/, count: 0
    assert_select ".dd-sidebar a", text: "Departures", count: 0
    assert_no_match COST_WORDS, response.body

    get reseller_offer_path(@alpha.offering)
    assert_response :success
    assert_select "th", text: "Places left"
    assert_select "tr", text: /O01.*left/m
    assert_no_match COST_WORDS, response.body

    WithdrawOffering.new(agency: @agency, actor: @staff, publication: OfferingPublication.open.find_by!(offering: @alpha.offering, reseller: @alpha.reseller)).call
    get reseller_offer_path(@alpha.offering)
    assert_response :not_found
    get reseller_root_path
    assert_select "p", text: /Nothing is published to Coral Coast Travel/
    assert_select "tr", text: /#{@booking.booking_reference}/, message: "its open bookings stay"
  end

  test "R-03 serves only the reseller's own bookings, with charges and balance read-only and no cost (ACC-14, CMN-19, CMN-52)" do
    sign_in_as @dana
    BookingProgress::STEPS.excluding("money").each do |step|
      get reseller_client_booking_path(@booking, step:)
      assert_response :success, step
      assert_no_match COST_WORDS, response.body, step
    end
    get reseller_client_booking_path(@booking, step: "travelers")
    assert_select "form#new-traveler"
    assert_select "input#traveler_q", count: 0, message: "never searches the agency's directory"
    assert_select "a", text: "Add legal name and date of birth", count: 0
    get reseller_client_booking_path(@booking, step: "price")
    assert_select "form#adjust-installments", count: 0
    assert_select "#reseller-payments", text: /Payments are recorded by Harbor Travel/

    post reseller_client_booking_acceptances_path(@booking), params: { booking_acceptance: { accepted_by: "Mateo Rivera", acceptance_method: "in_person", note: "In person." } }
    post reseller_client_booking_confirmation_path(@booking)
    assert_redirected_to reseller_client_booking_path(@booking, step: "confirm", anchor: "confirm")
    assert @booking.reload.status_confirmed?
    get reseller_client_booking_path(@booking, step: "money")
    assert_response :success
    assert_select "#booking-installments table"
    assert_select "#booking-balance", text: /Still due/
    assert_no_match COST_WORDS, response.body
    assert_select "a", text: "Record a payment", count: 0

    [ @alpha.bookings.fetch("BK-101"), @alpha.bookings.fetch("BK-104") ].each do |other|
      get reseller_client_booking_path(other)
      assert_response :not_found
      post reseller_client_booking_hold_path(other)
      assert_response :not_found
    end
    get reseller_client_booking_path(SecureRandom.uuid_v7)
    assert_response :not_found
  end

  test "a reseller starts a booking for a new client on a published offer, and edits its travelers (CLT-25, D-99 (1))" do
    sign_in_as @dana
    get new_reseller_offer_booking_path(@alpha.offering)
    assert_select "h1", text: "Start a booking"
    post reseller_offer_bookings_path(@alpha.offering), params: { booking_start: { first_name: " ", last_name: "Okafor", traveling: "1" } }
    assert_response :unprocessable_entity
    assert_select "input#booking_start_first_name[aria-invalid=true]"

    post reseller_offer_bookings_path(@alpha.offering), params: { booking_start: { first_name: "Ines", last_name: "Okafor", traveling: "1", date_of_birth: "1988-04-12" } }
    booking = ResellerScope.new(@dana).bookings.where.not(id: @booking.id).sole
    assert_redirected_to reseller_client_booking_path(booking, step: "travelers")
    ines = booking.booking_travelers.sole.traveler
    get edit_reseller_traveler_path(ines, booking_id: booking.id)
    assert_response :success
    patch reseller_traveler_path(ines, booking_id: booking.id), params: { traveler: { given_names: "Ines", middle_name: "Ada", surname: "Okafor", date_of_birth: "1988-04-12", lock_version: ines.lock_version } }
    assert_redirected_to reseller_client_booking_path(booking, step: "travelers")
    assert_equal "Ines Ada Okafor", ines.reload.legal_name

    nadia = @alpha.bookings.fetch("BK-101").booking_travelers.first.traveler
    get edit_reseller_traveler_path(nadia)
    assert_response :not_found
  end

  test "S-04 invites reseller users, and the directory filters clients a reseller created (ACC-13, D-78, question 7)" do
    sign_in_as @admin
    get reseller_path(@alpha.reseller)
    assert_select "#reseller-users li", text: /Dana Whitfield.*Active.*dana@coralcoast.example/m
    get new_reseller_user_path(@alpha.reseller)
    assert_response :success
    post reseller_users_path(@alpha.reseller), params: { agency_user: { email_address: "dana@coralcoast.example", first_name: "Dana", last_name: "Again" } }
    assert_response :unprocessable_entity
    assert_select "input#agency_user_email_address[aria-invalid=true]"
    post reseller_users_path(@alpha.reseller), params: { agency_user: { email_address: "jo@coralcoast.example", first_name: "Jo", last_name: "Lane" } }
    assert_redirected_to reseller_path(@alpha.reseller, anchor: "reseller-users")
    assert @alpha.reseller.agency_users.exists?(email_address: "jo@coralcoast.example", user_type: "reseller", status: "invited")

    get clients_path(creator: "reseller", status: "all")
    assert_select "td, th", text: /Mateo Rivera/
    assert_select "td, th", text: /Nadia Rowan/, count: 0
    get client_person_path(@booking.client_trip.client.client_person)
    assert_select "div", text: /Created by\s*Dana Whitfield, Coral Coast Travel/

    sign_in_as @baseline
    get new_reseller_user_path(@alpha.reseller)
    assert_redirected_to root_path
  end
end
