require "test_helper"

# Slice 1 step 9b: the reseller's commands (ACC-14, ACC-15, BKG-56, CLT-25,
# CMN-19, DEP-10, D-78, D-99; step 9 plan, questions 3, 5, 8 and 9).
class ResellerPathTest < ActiveSupport::TestCase
  setup do
    set_clock Time.utc(2027, 1, 10, 15)
    @agency = agencies(:harbor)
    @admin = agency_users(:harbor_admin)
    @staff = agency_users(:harbor_staff) # Departure management
    @baseline = agency_users(:harbor_baseline_staff)
    @alpha = AlphaFixture.load!(agency: @agency, actor: @admin, bookings: :held)
    @dana = @alpha.reseller_user
    @booking = @alpha.bookings.fetch("BK-105")
  end

  test "the reseller creates BK-105 with its client and travelers, owned and sold by its relationship (D-99 (1), ACC-18, CLT-25)" do
    assert_equal [ "reseller", @alpha.reseller, "reseller", @alpha.reseller, @dana ],
      [ @booking.owner_kind, @booking.owner_reseller, @booking.seller_kind, @booking.seller_reseller, @booking.created_by ]
    client = @booking.client_trip.client
    assert_equal @dana, client.created_by
    assert_equal [ @dana ] * 3, client.travelers.map(&:created_by)
    assert_equal %w[Mateo Elena Luca], @booking.booking_travelers.map { |row| row.traveler.given_names }
    assert_equal :held, @booking.hold_state.first
    assert AuditEvent.where(action: "client_booking.created", actor_agency_user_id: @dana.id).exists?
    assert_equal [ @booking ], ResellerScope.new(@dana).bookings.to_a
    assert_equal [ @alpha.offering ], ResellerScope.new(@dana).offerings.to_a
    assert_not ResellerScope.new(@staff).active?
  end

  test "a reseller starts a booking only on an offer published to it, with no duplicate check (D-78)" do
    booking = StartResellerBooking.new(agency: @agency, actor: @dana, offering: @alpha.offering,
      person: { first_name: "Nadia", last_name: "Rowan" }, traveling: true, date_of_birth: "1979-12-02").call.record
    assert_equal 2, @agency.client_people.where(first_name: "Nadia", last_name: "Rowan").count, "the agency's Nadia Rowan is never offered"
    assert_equal [ "Nadia Rowan" ], booking.booking_travelers.map(&:display_name)

    WithdrawOffering.new(agency: @agency, actor: @staff, publication: OfferingPublication.open.find_by!(offering: @alpha.offering, reseller: @alpha.reseller)).call
    assert_raises(ActiveRecord::RecordNotFound) do
      StartResellerBooking.new(agency: @agency, actor: @dana, offering: @alpha.offering, person: { first_name: "Ines", last_name: "Okafor" }).call
    end
    refused = assert_raises(AgencyCommand::Error) do
      StartResellerBooking.new(agency: @agency, actor: @staff, offering: @alpha.offering, person: { first_name: "Ines", last_name: "Okafor" }).call
    end
    assert_equal :unauthorized, refused.code
  end

  test "a reseller reaches only the bookings its relationship owns, and only the travelers it can see (ACC-14, CLT-25, SC-ACC-03)" do
    agency_booking = @alpha.bookings.fetch("BK-101")
    assert_raises(ActiveRecord::RecordNotFound) { HoldBookingSpace.new(agency: @agency, actor: @dana, booking: agency_booking).call }
    assert_raises(ActiveRecord::RecordNotFound) { DiscardClientBooking.new(agency: @agency, actor: @dana, booking: agency_booking).call }

    nadia = agency_booking.booking_travelers.first.traveler
    refused = assert_raises(AgencyCommand::Error) do
      SaveBookingTraveler.new(agency: @agency, actor: @dana, booking: @booking, attributes: { traveler_id: nadia.id }).call
    end
    assert_match(/Traveler must be one of this agency's/, refused.message)
    refused = assert_raises(AgencyCommand::Error) do
      AddTravelerToBooking.new(agency: @agency, actor: @dana, booking: @booking, traveler: nadia, relationship: "other").call
    end
    assert_equal :unauthorized, refused.code
    assert_raises(ActiveRecord::RecordNotFound) do
      SaveTraveler.new(agency: @agency, actor: @dana, traveler: nadia, attributes: { surname: "Changed" }).call
    end
    mateo = @booking.booking_travelers.first.traveler
    SaveTraveler.new(agency: @agency, actor: @dana, traveler: mateo, attributes: { middle_name: "Jose" }, lock_version: mateo.lock_version).call
    assert_equal "Mateo Jose Rivera", mateo.reload.legal_name

    bayside = SaveReseller.new(agency: @agency, actor: @admin, attributes: { name: "Bayside Journeys" }).call.record
    AssignClientBooking.new(agency: @agency, actor: @staff, booking: @booking, reseller: bayside).call
    assert_raises(ActiveRecord::RecordNotFound) { ExtendBookingHold.new(agency: @agency, actor: @dana, booking: @booking.reload).call }
    assert_empty ResellerScope.new(@dana).bookings
    assert_equal @alpha.reseller, @booking.reload.seller_reseller, "reassignment leaves the seller of record"
  end

  test "a reseller holds only on a published offer, and discards only while the hold is active (BKG-56, question 5)" do
    WithdrawOffering.new(agency: @agency, actor: @staff, publication: OfferingPublication.open.find_by!(offering: @alpha.offering, reseller: @alpha.reseller)).call
    ReleaseBookingHold.new(agency: @agency, actor: @dana, booking: @booking).call
    refused = assert_raises(AgencyCommand::Error) { HoldBookingSpace.new(agency: @agency, actor: @dana, booking: @booking.reload).call }
    assert_match(/isn't published to Coral Coast Travel, so space can't be held/, refused.message)

    refused = assert_raises(AgencyCommand::Error) { DiscardClientBooking.new(agency: @agency, actor: @dana, booking: @booking.reload).call }
    assert_match(/only while its hold is active/, refused.message)
    DiscardClientBooking.new(agency: @agency, actor: @baseline, booking: @booking.reload).call
    assert @booking.reload.status_discarded?
  end

  test "a reseller discards its held booking, releasing the space at once (BKG-56)" do
    DiscardClientBooking.new(agency: @agency, actor: @dana, booking: @booking).call
    assert @booking.reload.status_discarded?
    assert @booking.inventory_allocations.all?(&:state_released?)
  end

  test "a reseller confirms only at the offering's current prices and terms; staff confirm at superseded ones (DEP-10)" do
    RecordBookingAcceptance.new(agency: @agency, actor: @dana, booking: @booking,
      attributes: { accepted_by: "Mateo Rivera", acceptance_method: "in_person", note: "Accepted in person." }).call
    StartNextClientTermsVersion.new(agency: @agency, actor: @staff, departure: @alpha.departure.reload).call
    refused = assert_raises(AgencyCommand::Error) { ConfirmClientBooking.new(agency: @agency, actor: @dana, booking: @booking.reload).call }
    assert_match(/differ from the package's current ones, so the agency must confirm it/, refused.message)
    assert @booking.reload.status_draft?

    ConfirmClientBooking.new(agency: @agency, actor: @baseline, booking: @booking.reload).call
    assert @booking.reload.status_confirmed?
  end

  test "a reseller confirms its booking at the current prices and terms (BKG-45, ACC-15)" do
    RecordBookingAcceptance.new(agency: @agency, actor: @dana, booking: @booking,
      attributes: { accepted_by: "Mateo Rivera", acceptance_method: "in_person", note: "Accepted in person." }).call
    ConfirmClientBooking.new(agency: @agency, actor: @dana, booking: @booking.reload).call
    assert @booking.reload.status_confirmed?
    assert_equal @dana.id, AuditEvent.find_by!(action: "client_booking.confirmed", subject_id: @booking.id).actor_agency_user_id
  end

  test "money, supplier, Departure and directory commands refuse a reseller (ACC-15, CMN-19, question 8)" do
    trip = @booking.client_trip
    agency_trip = @alpha.bookings.fetch("BK-101").client_trip
    commands = {
      "record a payment" => -> { RecordClientPayment.new(agency: @agency, actor: @dana, trip:, attributes: { payer_client_id: trip.client_id, paid_on: "2027-01-10", amount: "100", route: "agency", payment_method: "check" }).call },
      "adjust installments" => -> { AdjustInstallmentProposals.new(agency: @agency, actor: @dana, booking: @booking, rows: []).call },
      "publish" => -> { PublishOffering.new(agency: @agency, actor: @dana, offering: @alpha.offering, reseller: @alpha.reseller).call },
      "assign" => -> { AssignClientBooking.new(agency: @agency, actor: @dana, booking: @booking, reseller: nil).call },
      "set the seller" => -> { SetBookingSellerOfRecord.new(agency: @agency, actor: @dana, booking: @booking, reseller: nil).call },
      "create a client" => -> { CreateIndividualClient.new(agency: @agency, actor: @dana, names: { first_name: "Ines", last_name: "Okafor" }).call },
      "create a traveler" => -> { SaveTraveler.new(agency: @agency, actor: @dana, attributes: { given_names: "Ines", surname: "Okafor" }).call },
      "start a staff booking" => -> { StartClientBooking.new(agency: @agency, actor: @dana, departure: @alpha.departure, person: { first_name: "Ines", last_name: "Okafor" }).call },
      "edit the Departure" => -> { UpdateDeparture.new(agency: @agency, actor: @dana, departure: @alpha.departure, attributes: { name: "Changed" }, lock_version: @alpha.departure.reload.lock_version).call },
      "edit client terms" => -> { StartNextClientTermsVersion.new(agency: @agency, actor: @dana, departure: @alpha.departure).call },
      "discard an arrangement" => -> { DiscardSupplierArrangement.new(agency: @agency, actor: @dana, departure: @alpha.departure, arrangement: @alpha.arrangements.fetch(:hotel), lock_version: nil).call },
      "save a reseller" => -> { SaveReseller.new(agency: @agency, actor: @dana, attributes: { name: "Mine" }).call },
      "invite a user" => -> { InviteAgencyUser.new(agency: @agency, actor: @dana, email_address: "x@example.com", first_name: "X", last_name: "Y", user_type: "reseller", reseller: @alpha.reseller).call }
    }
    commands.each do |name, command|
      error = assert_raises(AgencyCommand::Error, name) { command.call }
      assert_equal :unauthorized, error.code, name
    end
    assert_raises(ActiveRecord::RecordNotFound) { CreateClientBooking.new(agency: @agency, actor: @dana, trip: agency_trip).call }
  end

  test "an Agency Admin or staff with Reseller relationships invites a reseller user to an active relationship (ACC-13, question 3)" do
    refused = assert_raises(AgencyCommand::Error) { invite!(@staff) }
    assert_equal :unauthorized, refused.code
    @staff.user_permissions.create!(agency: @agency, permission: "reseller_relationships", user_type: "staff")
    user = invite!(@staff.reload).record
    assert_equal [ "reseller", "invited", @alpha.reseller ], [ user.user_type, user.status, user.reseller ]
    assert_equal @alpha.reseller.id, AuditEvent.find_by!(action: "agency_user.invited", subject_id: user.id).details["reseller_id"]

    refused = assert_raises(AgencyCommand::Error) do
      InviteAgencyUser.new(agency: @agency, actor: @admin, email_address: "sam@coralcoast.example", first_name: "Sam", last_name: "Hale", user_type: "reseller").call
    end
    assert_match(/Choose a reseller relationship/, refused.message)
    assert_raises(ActiveRecord::RecordNotFound) do
      InviteAgencyUser.new(agency: @agency, actor: @admin, email_address: "sam@coralcoast.example", first_name: "Sam", last_name: "Hale", user_type: "reseller",
        reseller: Reseller.create!(agency: agencies(:cove), name: "Cove Partner")).call
    end
  end

  private

  def invite!(actor)
    InviteAgencyUser.new(agency: @agency, actor:, email_address: "jo@coralcoast.example", first_name: "Jo", last_name: "Lane", user_type: "reseller", reseller: @alpha.reseller).call
  end
end
