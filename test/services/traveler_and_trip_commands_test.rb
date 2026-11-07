require "test_helper"

# Slice 1 step 6a: CLT-02, CLT-05, CLT-06, CLT-09 to CLT-11, CLT-28, OVR-02, REF-04, D-94.
class TravelerAndTripCommandsTest < ActiveSupport::TestCase
  setup do
    @agency = agencies(:harbor)
    @admin = agency_users(:harbor_admin)
    @staff = agency_users(:harbor_baseline_staff)
    @client = CreateIndividualClient.new(agency: @agency, actor: @staff, names: { first_name: "Sofia", last_name: "Bennett" }, also_traveling: true).call.record
  end

  test "a client who is also traveling gets a traveler with the same name, linked as Self (CLT-11)" do
    link = @client.traveler_links.sole
    assert link.related_as_self?
    assert_equal [ "Sofia", "Bennett", nil ], link.traveler.values_at(:given_names, :surname, :date_of_birth)
    assert AuditEvent.exists?(subject_id: @client.id, action: "client.traveler_linked")
  end

  test "baseline staff save a traveler with details missing, then complete it; a bad date is refused, not dropped" do
    traveler = traveler!(given_names: "Milo")
    assert_equal "Milo", traveler.display_name
    assert_not traveler.legal_name_complete?

    error = assert_raises(AgencyCommand::Error) do
      SaveTraveler.new(agency: @agency, actor: @staff, traveler:, attributes: { date_of_birth: "2025-02-30" }, lock_version: traveler.lock_version).call
    end
    assert_match(/Date of birth must be a date/, error.message)

    SaveTraveler.new(agency: @agency, actor: @staff, traveler:, lock_version: traveler.lock_version,
      attributes: { surname: "Bennett", date_of_birth: "2025-03-14", email_address: " Milo@Example.TEST ", gender: "male" }).call
    traveler.reload
    assert traveler.legal_name_complete?
    assert_equal [ 2, "milo@example.test" ], [ traveler.age_on(Date.new(2027, 11, 6)), traveler.email_address ]
    assert_equal %w[date_of_birth email_address gender surname],
      AuditEvent.where(subject_id: traveler.id, action: "traveler.updated").sole.details["changed_fields"]

    stale = assert_raises(AgencyCommand::Error) do
      SaveTraveler.new(agency: @agency, actor: @staff, traveler:, attributes: { suffix: "Jr" }, lock_version: 0).call
    end
    assert_equal :conflict, stale.code
  end

  test "a traveler needs some name, and a profile is one person" do
    error = assert_raises(AgencyCommand::Error) { traveler!(date_of_birth: "2000-01-01") }
    assert_match(/Surname or given names are required/, error.message)
    assert_raises(ActiveRecord::StatementInvalid) do
      Traveler.transaction(requires_new: true) { Traveler.insert_all!([ { agency_id: @agency.id, given_names: nil, surname: nil } ]) }
    end
  end

  test "travelers link to clients with a relationship, once each; Self only for a person client (CLT-09)" do
    ava = traveler!(given_names: "Ava", surname: "Bennett", link_client: @client, relationship: "family_member")
    assert_equal "family_member", @client.traveler_links.find_by!(traveler: ava).relationship

    duplicate = assert_raises(AgencyCommand::Error) { link!(@client, ava, "other") }
    assert_match(/already linked/, duplicate.message)
    second_self = assert_raises(AgencyCommand::Error) { link!(@client, traveler!(given_names: "Other"), "self") }
    assert_match(/Self/, second_self.message)

    organization = CreateOrganizationClient.new(agency: @agency, actor: @staff, names: { display_name: "Bennett Holdings" }).call.record
    refused = assert_raises(AgencyCommand::Error) { link!(organization, ava, "self") }
    assert_match(/Self is only for a person client/, refused.message)
    assert_raises(ActiveRecord::StatementInvalid) do
      TravelerLink.transaction(requires_new: true) do
        TravelerLink.insert_all!([ { agency_id: @agency.id, client_id: organization.id, traveler_id: ava.id, relationship: "self" } ])
      end
    end

    link!(organization, ava, "employee_or_member")
    UnlinkTraveler.new(agency: @agency, actor: @staff, link: organization.traveler_links.sole).call
    assert_empty organization.traveler_links.reload
    assert Traveler.exists?(ava.id), "unlinking leaves the traveler"
  end

  test "a trip has one responsible client and a reference issued at creation (CLT-02, REF-04, D-94)" do
    departure = CreateDeparture.new(agency: @agency, actor: @admin, attributes: { name: "Trip test", operating_currency: "USD" }).call.record
    first = trip!(client_id: @client.id, departure_id: departure.id)
    second = trip!(client_id: @client.id)
    assert_match ClientTrip::REFERENCE_FORMAT, first.trip_reference
    assert_equal first.trip_reference.delete_prefix("T-").to_i + 1, second.trip_reference.delete_prefix("T-").to_i
    assert_equal [ departure, nil ], [ first.departure, second.departure ]
    assert_equal "Not booked", first.status_label
    assert AuditEvent.exists?(subject_id: first.id, action: "client_trip.created")

    SaveClientTrip.new(agency: @agency, actor: @staff, trip: second, attributes: { departure_id: departure.id }, lock_version: second.lock_version).call
    assert_equal departure, second.reload.departure
    assert_raises(ActiveRecord::StatementInvalid) do
      ClientTrip.transaction(requires_new: true) { ClientTrip.where(id: first.id).update_all(trip_reference: "T-99999") }
    end
  end

  test "a trip needs an active client of this agency and one of its Departures" do
    ChangeClientStatus.new(agency: @agency, actor: @admin, client: @client, status: "inactive", lock_version: @client.lock_version).call
    assert_match(/inactive/, assert_raises(AgencyCommand::Error) { trip!(client_id: @client.id) }.message)

    other = CreateIndividualClient.new(agency: agencies(:cove), actor: agency_users(:cove_admin), names: { first_name: "Cove", last_name: "Client" }).call.record
    assert_match(/Client must be chosen/, assert_raises(AgencyCommand::Error) { trip!(client_id: other.id) }.message)
    cove_departure = CreateDeparture.new(agency: agencies(:cove), actor: agency_users(:cove_admin), attributes: { name: "Cove sailing", operating_currency: "USD" }).call.record
    active = CreateIndividualClient.new(agency: @agency, actor: @staff, names: { first_name: "Theo", last_name: "Rowan" }).call.record
    assert_match(/Departure must be one of this agency's/, assert_raises(AgencyCommand::Error) { trip!(client_id: active.id, departure_id: cove_departure.id) }.message)
  end

  private

  def traveler!(link_client: nil, relationship: nil, **attributes)
    SaveTraveler.new(agency: @agency, actor: @staff, attributes:, link_client:, relationship:).call.record
  end

  def link!(client, traveler, relationship)
    LinkTraveler.new(agency: @agency, actor: @staff, client:, traveler_id: traveler.id, relationship:).call
  end

  def trip!(**attributes)
    SaveClientTrip.new(agency: @agency, actor: @staff, attributes:).call.record
  end
end
