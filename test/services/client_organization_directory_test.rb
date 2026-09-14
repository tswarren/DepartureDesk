require "test_helper"

class ClientOrganizationDirectoryTest < ActiveSupport::TestCase
  setup do
    @agency = agencies(:harbor)
    @other = agencies(:cove)
    @admin = agency_users(:harbor_admin)
    @staff = agency_users(:harbor_staff)
  end

  test "organization client creation is atomic when duplicate review is required" do
    first = create_organization_client(display_name: "Harbor Tours").record

    assert_equal "CL-000001", first.client_reference
    assert_raises(AgencyCommand::DuplicateReviewRequired) do
      create_organization_client(display_name: "Harbor Tours")
    end
    assert_equal 1, @agency.clients.count
    assert_equal 1, @agency.client_organizations.count
    assert_equal 2, reference_sequences(:harbor_client).reload.next_value
  end

  test "organization client creation replays acknowledged composite create" do
    create_organization_client(display_name: "Replay Tours")
    error = assert_raises(AgencyCommand::DuplicateReviewRequired) { create_organization_client(display_name: "Replay Tours") }
    created = create_organization_client(
      display_name: "Replay Tours",
      acknowledgement_token: error.token,
      acknowledgement_reason: "confirmed_distinct"
    )
    replayed = create_organization_client(
      display_name: "Replay Tours",
      acknowledgement_token: error.token,
      acknowledgement_reason: "confirmed_distinct"
    )

    assert_equal :created, created.status
    assert_equal :replayed, replayed.status
    assert_equal created.record, replayed.record
    assert_equal 2, @agency.clients.count
  end

  test "promoting an organization with an inactive client reports already exists" do
    organization = CreateClientOrganization.new(agency: @agency, actor: @admin, names: { display_name: "Dormant Org" }).call.record
    client = CreateClientForOrganization.new(agency: @agency, actor: @admin, client_organization: organization).call.record
    ChangeClientStatus.new(agency: @agency, actor: @admin, client: client, status: "inactive", lock_version: client.lock_version).call

    error = assert_raises(AgencyCommand::Error) do
      CreateClientForOrganization.new(agency: @agency, actor: @admin, client_organization: organization).call
    end
    assert_equal :already_exists, error.code
  end

  test "adding an existing person as organization contact does not run identity duplicate review" do
    organization = create_organization("Signal-Free Org")
    person = @agency.client_people.create!(first_name: "Duplicated", last_name: "Contact")
    @agency.client_people.create!(first_name: "Duplicated", last_name: "Contact")

    result = AddClientOrganizationContact.new(
      agency: @agency,
      actor: @admin,
      client_organization: organization,
      client_person: person,
      attributes: { starts_on: Date.new(2026, 1, 1), primary: true }
    ).call

    assert_equal :created, result.status
    assert_equal person.id, result.record.client_person_id
  end

  test "creating a person and organization contact is atomic and never creates a client" do
    organization = create_organization("Composite Contact Org")
    @agency.client_people.create!(first_name: "Ada", last_name: "Contact")
    before_counts = [ @agency.client_people.count, @agency.client_organization_contacts.count, @agency.clients.count ]

    error = assert_raises(AgencyCommand::DuplicateReviewRequired) do
      CreateClientPersonAndOrganizationContact.new(
        agency: @agency,
        actor: @admin,
        client_organization: organization,
        names: { first_name: "Ada", last_name: "Contact" },
        attributes: { starts_on: Date.new(2026, 1, 1) }
      ).call
    end
    assert_equal before_counts, [ @agency.client_people.count, @agency.client_organization_contacts.count, @agency.clients.count ]

    result = CreateClientPersonAndOrganizationContact.new(
      agency: @agency,
      actor: @admin,
      client_organization: organization,
      names: { first_name: "Ada", last_name: "Contact" },
      attributes: { starts_on: Date.new(2026, 1, 1) },
      acknowledgement_token: error.token,
      acknowledgement_reason: "confirmed_distinct"
    ).call

    assert_equal :created, result.status
    assert_equal before_counts[0] + 1, @agency.client_people.count
    assert_equal before_counts[1] + 1, @agency.client_organization_contacts.count
    assert_equal before_counts[2], @agency.clients.count
    assert_equal [ "client_person.duplicate_override" ], AuditEvent.where(action: "client_person.duplicate_override").pluck(:action)
    assert_equal 0, AuditEvent.where(action: "client_organization.duplicate_override").count
  end

  test "ending and primary changes require fresh lock versions" do
    organization = create_organization("Lock Org")
    first = add_contact(organization, @agency.client_people.create!(first_name: "First", last_name: "Contact"), primary: true)
    second = add_contact(organization, @agency.client_people.create!(first_name: "Second", last_name: "Contact"), primary: false)

    first.update!(title: "Changed")
    error = assert_raises(AgencyCommand::Error) do
      EndClientOrganizationContact.new(agency: @agency, actor: @admin, client_organization_contact: first, lock_version: 0, replacement_primary_contact: second).call
    end
    assert_equal :conflict, error.code

    second.update!(title: "Changed")
    error = assert_raises(AgencyCommand::Error) do
      ChangeClientOrganizationPrimaryContact.new(agency: @agency, actor: @admin, client_organization_contact: second, lock_version: 0).call
    end
    assert_equal :conflict, error.code
  end

  test "ending an already ended assignment with matching lock version is a noop" do
    organization = create_organization("Already Ended Org")
    assignment = add_contact(organization, @agency.client_people.create!(first_name: "Ended", last_name: "Contact"))
    EndClientOrganizationContact.new(agency: @agency, actor: @admin, client_organization_contact: assignment, lock_version: assignment.lock_version).call
    ended = assignment.reload
    audits = AuditEvent.where(action: "client_organization.contact_ended", subject_id: organization.id).count

    result = EndClientOrganizationContact.new(agency: @agency, actor: @admin, client_organization_contact: ended, lock_version: ended.lock_version).call

    assert_equal :noop, result.status
    assert_equal audits, AuditEvent.where(action: "client_organization.contact_ended", subject_id: organization.id).count
  end

  test "organization inactivation cascades current assignments and contact points" do
    organization = create_organization("Cascade Org")
    person = @agency.client_people.create!(first_name: "Casey", last_name: "Cascade")
    assignment = add_contact(organization, person, primary: true)
    email = CreateClientOrganizationEmailAddress.new(
      agency: @agency, actor: @admin, client_organization: organization, attributes: { address: "info@example.com", preferred: true }
    ).call.record
    website = CreateClientOrganizationWebsite.new(
      agency: @agency, actor: @admin, client_organization: organization, attributes: { url: "example.com", preferred: true }
    ).call.record

    result = ChangeClientOrganizationStatus.new(
      agency: @agency, actor: @admin, client_organization: organization, status: "inactive", lock_version: organization.lock_version
    ).call

    assert_equal :updated, result.status
    assert_equal "inactive", organization.reload.status
    assert_equal Time.current.in_time_zone(@agency.default_timezone).to_date, assignment.reload.ends_on
    assert_not assignment.primary?
    assert_equal "inactive", email.reload.status
    assert_not email.preferred?
    assert_equal "inactive", website.reload.status
    assert_not website.preferred?
    audit = AuditEvent.where(action: "client_organization.inactivated", subject_id: organization.id).last
    assert_equal [ assignment.id ], audit.details["ended_assignment_ids"]
    assert_equal %w[ClientOrganizationEmailAddress ClientOrganizationWebsite], audit.details["inactivated_contact_points"].map { |point| point["type"] }.sort
  end

  test "current organization assignment blocks person inactivation" do
    organization = create_organization("Person Block Org")
    person = @agency.client_people.create!(first_name: "Blocked", last_name: "Person")
    add_contact(organization, person)

    error = assert_raises(AgencyCommand::Error) do
      ChangeClientPersonStatus.new(agency: @agency, actor: @admin, client_person: person, status: "inactive", lock_version: person.lock_version).call
    end
    assert_equal :dependency_exists, error.code
  end

  test "organization duplicate finder and search reject actor agency mismatch" do
    assert_raises_with_code(:unauthorized) do
      FindClientOrganizationDuplicates.call(agency: @other, actor: @admin, names: { display_name: "Cove" })
    end
    assert_raises_with_code(:unauthorized) do
      SearchClientDirectory.call(agency: @other, actor: @admin, query: "Cove")
    end
  end

  test "overlapping assignment conflicts are translated to domain errors" do
    organization = create_organization("Conflict Org")
    person = @agency.client_people.create!(first_name: "Overlap", last_name: "Contact")
    add_contact(organization, person, starts_on: Date.new(2026, 1, 1), ends_on: Date.new(2026, 1, 31))

    error = assert_raises(AgencyCommand::Error) do
      AddClientOrganizationContact.new(
        agency: @agency,
        actor: @admin,
        client_organization: organization,
        client_person: person,
        attributes: { starts_on: Date.new(2026, 1, 15), ends_on: Date.new(2026, 2, 15) }
      ).call
    end
    assert_equal :conflict, error.code
  end

  private

  def create_organization_client(display_name:, acknowledgement_token: nil, acknowledgement_reason: nil)
    CreateOrganizationClient.new(
      agency: @agency,
      actor: @admin,
      names: { display_name: display_name },
      acknowledgement_token: acknowledgement_token,
      acknowledgement_reason: acknowledgement_reason
    ).call
  end

  def create_organization(display_name)
    CreateClientOrganization.new(agency: @agency, actor: @admin, names: { display_name: display_name }).call.record
  end

  def add_contact(organization, person, starts_on: Date.new(2026, 1, 1), ends_on: nil, primary: false)
    AddClientOrganizationContact.new(
      agency: @agency,
      actor: @admin,
      client_organization: organization,
      client_person: person,
      attributes: { starts_on: starts_on, ends_on: ends_on, primary: primary }
    ).call.record
  end

  def assert_raises_with_code(code, &block)
    error = assert_raises(AgencyCommand::Error, &block)
    assert_equal code, error.code
  end
end
