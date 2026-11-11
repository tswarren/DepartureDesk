require "test_helper"

# Slice 1 step 9a: reseller relationships (ACC-13, DOC-08), publishing to
# their channels (DEP-07 to DEP-09, D-68), a booking's owner and seller of
# record (ACC-18, FIN-05) and who created a profile (D-78); step 9 plan
# questions 3, 4, 6 and 7.
class ResellerStaffSideTest < ActiveSupport::TestCase
  setup do
    set_clock Time.utc(2027, 1, 10, 15)
    @agency = agencies(:harbor)
    @admin = agency_users(:harbor_admin)
    @staff = agency_users(:harbor_staff) # Departure management
    @baseline = agency_users(:harbor_baseline_staff)
    @alpha = AlphaFixture.load!(agency: @agency, actor: @admin, bookings: :confirmed)
    set_clock Time.utc(2027, 2, 3, 15)
    @reseller = SaveReseller.new(agency: @agency, actor: @admin, attributes: { name: "Bayside Journeys" }).call.record
  end

  test "an Agency Admin or staff with Reseller relationships authorizes a reseller, Active with direct contact on (ACC-13, DOC-08)" do
    assert_equal [ "Bayside Journeys", "active", true ], [ @reseller.name, @reseller.status, @reseller.direct_contact_allowed ]
    event = AuditEvent.find_by!(action: "reseller.authorized", subject_type: @reseller.class.name, subject_id: @reseller.id)
    assert_equal [ "Reseller", @admin.id ], [ event.subject_type, event.actor_agency_user_id ]

    refused = assert_raises(AgencyCommand::Error) { SaveReseller.new(agency: @agency, actor: @staff, attributes: { name: "Other" }).call }
    assert_equal :unauthorized, refused.code
    @staff.user_permissions.create!(agency: @agency, permission: "reseller_relationships", user_type: "staff")
    other = SaveReseller.new(agency: @agency, actor: @staff.reload, attributes: { name: "Harbor Lane Travel", direct_contact_allowed: "0" }).call.record
    assert_not other.direct_contact_allowed

    result = SaveReseller.new(agency: @agency, actor: @admin, reseller: @reseller, attributes: { name: "Bayside Journeys" }, lock_version: @reseller.lock_version).call
    assert_equal :noop, result.status
    SaveReseller.new(agency: @agency, actor: @admin, reseller: @reseller, attributes: { direct_contact_allowed: "0" }, lock_version: @reseller.lock_version).call
    assert_equal [ "direct_contact_allowed" ], AuditEvent.find_by!(action: "reseller.updated", subject_type: @reseller.class.name, subject_id: @reseller.id).details["changed_fields"]
    stale = assert_raises(AgencyCommand::Error) do
      SaveReseller.new(agency: @agency, actor: @admin, reseller: @reseller, attributes: { name: "Late" }, lock_version: 0).call
    end
    assert_equal :conflict, stale.code
    assert_raises(AgencyCommand::Error) { SaveReseller.new(agency: @agency, actor: @admin, attributes: { name: " " }).call }
  end

  test "only a Ready to sell Departure is published, once per channel, and withdrawing keeps the record (DEP-07, DEP-09, SC-DEP-02)" do
    publication = publish!
    assert publication.open?
    assert_equal [ @reseller, @staff ], [ publication.reseller, publication.published_by ]
    assert AuditEvent.exists?(action: "departure.offering_published", subject_type: @alpha.departure.class.name, subject_id: @alpha.departure.id)

    again = assert_raises(AgencyCommand::Error) { publish! }
    assert_match(/already published to Bayside Journeys/, again.message)
    assert_raises(AgencyCommand::Error) { PublishOffering.new(agency: @agency, actor: @baseline, offering: @alpha.offering, reseller: @reseller).call }

    WithdrawOffering.new(agency: @agency, actor: @staff, publication:).call
    assert_not publication.reload.open?
    assert_equal @staff, publication.withdrawn_by
    assert_equal :noop, WithdrawOffering.new(agency: @agency, actor: @staff, publication:).call.status
    assert publish!.open?, "publishing again makes a new publication"
    assert_equal 2, @alpha.offering.publications.where(reseller: @reseller).count

    return_to_draft!
    refused = assert_raises(AgencyCommand::Error) { publish! }
    assert_match(/is a draft. Mark it Ready to sell before publishing/, refused.message)
  end

  test "returning to Draft withdraws every open publication and leaves bookings as they are (DEP-08)" do
    other = SaveReseller.new(agency: @agency, actor: @admin, attributes: { name: "Harbor Lane Travel" }).call.record
    publications = [ publish!, publish!(other), OfferingPublication.open.find_by!(offering: @alpha.offering, reseller: @alpha.reseller) ]
    statuses = @alpha.bookings.transform_values(&:status)
    return_to_draft!
    assert publications.map(&:reload).none?(&:open?)
    assert_equal publications.map(&:id).sort, AuditEvent.find_by!(action: "departure.returned_to_draft").details["withdrawn_publication_ids"].sort
    assert_equal statuses, @alpha.bookings.transform_values { |booking| booking.reload.status }
  end

  test "PostgreSQL keeps a publication's facts and allows one open publication per channel" do
    publication = publish!
    assert_rejected { OfferingPublication.where(id: publication.id).update_all(published_at: 1.day.ago) }
    assert_rejected { OfferingPublication.where(id: publication.id).delete_all }
    assert_rejected(ActiveRecord::RecordNotUnique) do
      OfferingPublication.insert!({ agency_id: @agency.id, offering_id: @alpha.offering.id, reseller_id: @reseller.id, published_at: Clock.current.now, published_by_id: @admin.id,
                                    created_at: Clock.current.now, updated_at: Clock.current.now })
    end
    publication.update_columns(withdrawn_at: Clock.current.now, withdrawn_by_id: @admin.id)
    assert_rejected { publication.update_columns(withdrawn_at: Clock.current.now + 1.minute) }
  end

  test "assignment changes the owner and never the seller of record; the seller is fixed once confirmed (ACC-18, FIN-05, SC-ACC-03)" do
    booking = @alpha.bookings.fetch("BK-101")
    AssignClientBooking.new(agency: @agency, actor: @staff, booking:, reseller: @reseller, lock_version: booking.lock_version).call
    booking.reload
    assert_equal [ "reseller", @reseller, "agency" ], [ booking.owner_kind, booking.owner_reseller, booking.seller_kind ]
    assert_equal({ "from_reseller_id" => nil, "to_reseller_id" => @reseller.id }, AuditEvent.find_by!(action: "client_booking.assigned").details.slice("from_reseller_id", "to_reseller_id"))
    assert_equal :noop, AssignClientBooking.new(agency: @agency, actor: @staff, booking:, reseller: @reseller).call.status

    fixed = assert_raises(AgencyCommand::Error) { SetBookingSellerOfRecord.new(agency: @agency, actor: @staff, booking:, reseller: @reseller).call }
    assert_match(/fixed once a booking is confirmed/, fixed.message)
    AssignClientBooking.new(agency: @agency, actor: @staff, booking:, reseller: nil).call
    assert_equal [ "agency", nil ], [ booking.reload.owner_kind, booking.owner_reseller_id ]

    draft = CreateClientBooking.new(agency: @agency, actor: @baseline, trip: booking.client_trip).call.record
    SetBookingSellerOfRecord.new(agency: @agency, actor: @staff, booking: draft, reseller: @reseller, lock_version: draft.lock_version).call
    AssignClientBooking.new(agency: @agency, actor: @staff, booking: draft.reload, reseller: nil).call
    assert_equal [ "agency", @reseller ], [ draft.reload.owner_kind, draft.seller_reseller ]

    [ AssignClientBooking, SetBookingSellerOfRecord ].each do |command|
      refused = assert_raises(AgencyCommand::Error) { command.new(agency: @agency, actor: @baseline, booking: draft, reseller: @reseller).call }
      assert_equal :unauthorized, refused.code
    end
    DiscardClientBooking.new(agency: @agency, actor: @baseline, booking: draft.reload).call
    assert_raises(AgencyCommand::Error) { AssignClientBooking.new(agency: @agency, actor: @staff, booking: draft.reload, reseller: @reseller).call }
  end

  test "another agency's reseller is not found, and PostgreSQL ties the owner and seller to their kinds" do
    cove = Reseller.create!(agency: agencies(:cove), name: "Cove Partner")
    booking = @alpha.bookings.fetch("BK-101")
    assert_raises(ActiveRecord::RecordNotFound) { AssignClientBooking.new(agency: @agency, actor: @staff, booking:, reseller: cove).call }
    assert_rejected { booking.update_columns(owner_kind: "reseller") }
    assert_rejected { booking.update_columns(seller_kind: "agency", seller_reseller_id: @reseller.id) }
    assert_rejected { booking.update_columns(owner_kind: "reseller", owner_reseller_id: cove.id) }
  end

  test "clients and travelers record who created them (D-78)" do
    client = CreateIndividualClient.new(agency: @agency, actor: @baseline, names: { first_name: "Ines", last_name: "Okafor" }, also_traveling: true).call.record
    assert_equal @baseline, client.created_by
    assert_equal [ @baseline ], client.travelers.map(&:created_by)
    traveler = SaveTraveler.new(agency: @agency, actor: @baseline, attributes: { given_names: "Ada", surname: "Okafor" }, link_client: client, relationship: "family_member").call.record
    assert_equal @baseline, traveler.created_by
  end

  private

  # A refused statement inside a savepoint, so the test's transaction goes on.
  def assert_rejected(error = ActiveRecord::StatementInvalid, &block)
    assert_raises(error) { ActiveRecord::Base.transaction(requires_new: true, &block) }
  end

  def publish!(reseller = @reseller)
    PublishOffering.new(agency: @agency, actor: @staff, offering: @alpha.offering, reseller:).call.record
  end

  def return_to_draft!
    departure = @alpha.departure.reload
    ReturnDepartureToDraft.new(agency: @agency, actor: @staff, departure:, reason: nil, lock_version: departure.lock_version).call
  end
end
