require "test_helper"

class ClientOrganizationDirectoryTest < ActiveSupport::TestCase
  setup do
    @agency = agencies(:harbor)
    @other = agencies(:cove)
    @admin = agency_users(:harbor_admin)
    @staff = agency_users(:harbor_staff)
    @viewer = agency_users(:harbor_viewer)
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
    assert_equal "That organization contact assignment conflicts with an existing assignment. Reload and try again.", error.message
    assert_no_match(/start date/i, error.message)
  end

  test "organization search matches reference legal name email phone locality postal and website" do
    client = create_organization_client(display_name: "Reference Search Org").record
    organization = client.client_organization
    legal = create_organization("Trade Name Org", legal_name: "Legal Search Holdings")
    email_org = create_organization("Email Search Org")
    CreateClientOrganizationEmailAddress.new(
      agency: @agency, actor: @admin, client_organization: email_org, attributes: { address: "org-search@example.com" }
    ).call
    phone_org = create_organization("Phone Search Org")
    CreateClientOrganizationPhoneNumber.new(
      agency: @agency, actor: @admin, client_organization: phone_org,
      attributes: { number: "202-555-0147", country_code: "US" }
    ).call
    locality_org = create_organization("Locality Search Org")
    CreateClientOrganizationPostalAddress.new(
      agency: @agency, actor: @admin, client_organization: locality_org,
      attributes: { line_1: "1 Pier", locality: "Provincetown", postal_code: "02657", country_code: "US" }
    ).call
    postal_org = create_organization("Postal Search Org")
    CreateClientOrganizationPostalAddress.new(
      agency: @agency, actor: @admin, client_organization: postal_org,
      attributes: { line_1: "2 Pier", locality: "Boston", postal_code: "02110", country_code: "US" }
    ).call
    website_org = create_organization("Website Search Org")
    CreateClientOrganizationWebsite.new(
      agency: @agency, actor: @admin, client_organization: website_org, attributes: { url: "org-search-host.example" }
    ).call

    assert_equal [ organization.id ], search_ids(client.client_reference, kind: "organizations")
    assert_equal [ legal.id ], search_ids("Legal Search Holdings", kind: "organizations")
    assert_equal [ email_org.id ], search_ids("org-search@example.com", kind: "organizations")
    assert_equal [ phone_org.id ], search_ids("2025550147", kind: "organizations")
    assert_equal [ locality_org.id ], search_ids("Provincetown", kind: "organizations")
    assert_equal [ postal_org.id ], search_ids("02110", kind: "organizations")
    assert_equal [ website_org.id ], search_ids("org-search-host.example", kind: "organizations")
  end

  test "search ranking prefers better ranks and match_kind follows the best rank" do
    better = create_organization("Shared Token Org")
    weaker = create_organization("Weaker Match Org")
    CreateClientOrganizationPostalAddress.new(
      agency: @agency, actor: @admin, client_organization: weaker,
      attributes: { line_1: "9 Dock", locality: "Shared Token", postal_code: "99999", country_code: "US" }
    ).call

    ranked = SearchClientDirectory.call(agency: @agency, actor: @admin, query: "Shared Token", kind: "organizations")
    assert_equal [ better.id, weaker.id ], ranked.records.map(&:id)
    assert_operator ranked.records.first.rank, :<, ranked.records.last.rank

    dual = create_organization("dual@example.com")
    CreateClientOrganizationEmailAddress.new(
      agency: @agency, actor: @admin, client_organization: dual, attributes: { address: "dual@example.com" }
    ).call
    match = SearchClientDirectory.call(agency: @agency, actor: @admin, query: "dual@example.com", kind: "organizations")
    assert_equal [ dual.id ], match.records.map(&:id)
    assert_equal 2, match.records.first.rank
    assert_equal "email", match.records.first.kind
  end

  test "viewer without contact detail permission does not match organization destinations" do
    organization = create_organization("Visible Name Org")
    CreateClientOrganizationEmailAddress.new(
      agency: @agency, actor: @admin, client_organization: organization, attributes: { address: "viewer-hidden@example.com" }
    ).call
    CreateClientOrganizationPhoneNumber.new(
      agency: @agency, actor: @admin, client_organization: organization,
      attributes: { number: "202-555-0188", country_code: "US" }
    ).call
    CreateClientOrganizationPostalAddress.new(
      agency: @agency, actor: @admin, client_organization: organization,
      attributes: { line_1: "1 Hidden", locality: "Viewerhide", postal_code: "02142", country_code: "US" }
    ).call
    CreateClientOrganizationWebsite.new(
      agency: @agency, actor: @admin, client_organization: organization, attributes: { url: "viewer-hide.example" }
    ).call

    assert_empty SearchClientDirectory.call(agency: @agency, actor: @viewer, query: "viewer-hidden@example.com", kind: "organizations").records
    assert_empty SearchClientDirectory.call(agency: @agency, actor: @viewer, query: "2025550188", kind: "organizations").records
    assert_empty SearchClientDirectory.call(agency: @agency, actor: @viewer, query: "Viewerhide", kind: "organizations").records
    assert_empty SearchClientDirectory.call(agency: @agency, actor: @viewer, query: "02142", kind: "organizations").records
    assert_empty SearchClientDirectory.call(agency: @agency, actor: @viewer, query: "viewer-hide.example", kind: "organizations").records
    assert_equal [ organization.id ], search_ids("Visible Name Org", actor: @viewer, kind: "organizations")
  end

  test "organization search caps ranked results with a fetch of 51" do
    51.times do |index|
      create_organization(format("Trunc Org %03d", index))
    end

    queries = []
    callback = ->(*, payload) { queries << payload if payload[:sql].include?("search_rank") }
    result = ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
      SearchClientDirectory.call(agency: @agency, actor: @admin, query: "Trunc Org", kind: "organizations")
    end
    capped = queries.last

    assert_equal 50, result.records.size
    assert result.truncated
    assert_match(/LIMIT \$\d+\z/, capped[:sql])
    assert_equal 51, Array(capped[:type_casted_binds]).last
  end

  test "an active client blocks organization inactivation" do
    client = create_organization_client(display_name: "Active Block Org").record
    organization = client.client_organization

    error = assert_raises(AgencyCommand::Error) do
      ChangeClientOrganizationStatus.new(
        agency: @agency, actor: @admin, client_organization: organization, status: "inactive", lock_version: organization.lock_version
      ).call
    end
    assert_equal :dependency_exists, error.code
  end

  test "organization must be reactivated before client reactivation and empty restoration keeps dependents inactive" do
    client = create_organization_client(display_name: "Lifecycle Org").record
    organization = client.client_organization
    email = CreateClientOrganizationEmailAddress.new(
      agency: @agency, actor: @admin, client_organization: organization, attributes: { address: "lifecycle@example.com", preferred: true }
    ).call.record

    ChangeClientStatus.new(agency: @agency, actor: @admin, client: client, status: "inactive", lock_version: client.lock_version).call
    ChangeClientOrganizationStatus.new(
      agency: @agency, actor: @admin, client_organization: organization, status: "inactive", lock_version: organization.lock_version
    ).call

    error = assert_raises(AgencyCommand::Error) do
      ChangeClientStatus.new(agency: @agency, actor: @admin, client: client.reload, status: "active", lock_version: client.lock_version).call
    end
    assert_equal :dependency_exists, error.code

    ChangeClientOrganizationStatus.new(
      agency: @agency, actor: @admin, client_organization: organization.reload, status: "active", lock_version: organization.lock_version
    ).call
    ChangeClientStatus.new(agency: @agency, actor: @admin, client: client.reload, status: "active", lock_version: client.lock_version).call
    assert_equal "active", organization.reload.status
    assert_equal "active", client.reload.status
    assert_equal "inactive", email.reload.status
    assert_not email.preferred?

    lonely = create_organization("Lonely Restore Org")
    lonely_email = CreateClientOrganizationEmailAddress.new(
      agency: @agency, actor: @admin, client_organization: lonely, attributes: { address: "lonely@example.com", preferred: true }
    ).call.record
    ChangeClientOrganizationStatus.new(
      agency: @agency, actor: @admin, client_organization: lonely, status: "inactive", lock_version: lonely.lock_version
    ).call
    ChangeClientOrganizationStatus.new(
      agency: @agency, actor: @admin, client_organization: lonely.reload, status: "active", lock_version: lonely.lock_version
    ).call
    assert_equal "active", lonely.reload.status
    assert_equal "inactive", lonely_email.reload.status
    assert_not lonely_email.preferred?
  end

  test "contact point duplicate review acknowledgement and replay cover email and postal name conjunctions" do
    email_owner = create_organization("Email Owner Org")
    CreateClientOrganizationEmailAddress.new(
      agency: @agency, actor: @admin, client_organization: email_owner, attributes: { address: "shared-org@example.com" }
    ).call
    email_other = create_organization("Email Other Org")
    assert_organization_contact_acknowledgement(
      command: CreateClientOrganizationEmailAddress,
      organization: email_other,
      attributes: { address: "shared-org@example.com" },
      candidate: email_owner,
      signal: "exact_email"
    )

    postal_owner = create_organization("Postal Twin Org")
    CreateClientOrganizationPostalAddress.new(
      agency: @agency, actor: @admin, client_organization: postal_owner,
      attributes: { line_1: "1 Dock", locality: "Cambridge", postal_code: "02139", country_code: "US" }
    ).call
    name_review = assert_raises(AgencyCommand::DuplicateReviewRequired) do
      CreateClientOrganization.new(agency: @agency, actor: @admin, names: { display_name: "Postal Twin Org" }).call
    end
    postal_other = CreateClientOrganization.new(
      agency: @agency, actor: @admin, names: { display_name: "Postal Twin Org" },
      acknowledgement_token: name_review.token, acknowledgement_reason: "confirmed_distinct"
    ).call.record
    assert_organization_contact_acknowledgement(
      command: CreateClientOrganizationPostalAddress,
      organization: postal_other,
      attributes: { line_1: "2 Pier", locality: "Cambridge", postal_code: "02140", country_code: "US" },
      candidate: postal_owner,
      signal: "name_and_locality",
      signals: %w[exact_display_name name_and_locality]
    )
  end

  test "parallel duplicate token submission creates once and replays without a second audit" do
    owner = create_organization("Parallel Owner Org")
    CreateClientOrganizationEmailAddress.new(
      agency: @agency, actor: @admin, client_organization: owner, attributes: { address: "parallel@example.com" }
    ).call
    organization = create_organization("Parallel Target Org")
    error = assert_raises(AgencyCommand::DuplicateReviewRequired) do
      CreateClientOrganizationEmailAddress.new(
        agency: @agency, actor: @admin, client_organization: organization, attributes: { address: "parallel@example.com" }
      ).call
    end

    created = CreateClientOrganizationEmailAddress.new(
      agency: @agency, actor: @admin, client_organization: organization, attributes: { address: "parallel@example.com" },
      acknowledgement_token: error.token, acknowledgement_reason: "shared_contact"
    ).call
    audits = AuditEvent.where(action: "client_organization.contact_updated", subject_id: organization.id).count
    overrides = AuditEvent.where(action: "client_organization.duplicate_override", subject_id: organization.id).count
    replayed = CreateClientOrganizationEmailAddress.new(
      agency: @agency, actor: @admin, client_organization: organization, attributes: { address: "parallel@example.com" },
      acknowledgement_token: error.token, acknowledgement_reason: "shared_contact"
    ).call

    assert_equal :created, created.status
    assert_equal :replayed, replayed.status
    assert_equal created.record, replayed.record
    assert_equal 1, organization.email_addresses.count
    assert_equal audits, AuditEvent.where(action: "client_organization.contact_updated", subject_id: organization.id).count
    assert_equal overrides, AuditEvent.where(action: "client_organization.duplicate_override", subject_id: organization.id).count
  end

  test "competing primary changes clear the prior primary and reject a stale lock version" do
    organization = create_organization("Primary Race Org")
    first = add_contact(organization, @agency.client_people.create!(first_name: "First", last_name: "Primary"), primary: true)
    second = add_contact(organization, @agency.client_people.create!(first_name: "Second", last_name: "Primary"), primary: false)

    ChangeClientOrganizationPrimaryContact.new(
      agency: @agency, actor: @admin, client_organization_contact: second, lock_version: second.lock_version
    ).call

    assert second.reload.primary?
    assert_not first.reload.primary?

    stale = assert_raises(AgencyCommand::Error) do
      ChangeClientOrganizationPrimaryContact.new(
        agency: @agency, actor: @admin, client_organization_contact: first, lock_version: 0
      ).call
    end
    assert_equal :conflict, stale.code
    assert second.reload.primary?
    assert_not first.reload.primary?
  end

  test "updating an organization contact rejects starts_on after ends_on" do
    organization = create_organization("Date Guard Org")
    assignment = add_contact(
      organization,
      @agency.client_people.create!(first_name: "Dated", last_name: "Contact"),
      starts_on: Date.new(2026, 1, 1),
      ends_on: Date.new(2026, 1, 31)
    )

    error = assert_raises(AgencyCommand::Error) do
      UpdateClientOrganizationContact.new(
        agency: @agency,
        actor: @admin,
        client_organization_contact: assignment,
        attributes: { starts_on: Date.new(2026, 2, 1), title: assignment.title, role_label: assignment.role_label },
        lock_version: assignment.lock_version
      ).call
    end
    assert_equal :invalid, error.code
    assert_equal "Start date cannot be after end date.", error.message
  end

  test "postal duplicates require name plus postal or locality and ignore shared zip alone" do
    owner = create_organization("Named Postal Org")
    CreateClientOrganizationPostalAddress.new(
      agency: @agency, actor: @admin, client_organization: owner,
      attributes: { line_1: "1 Dock", locality: "Somerville", postal_code: "02144", country_code: "US" }
    ).call

    assert_empty FindClientOrganizationDuplicates.call(
      agency: @agency, actor: @admin, names: {}, postal_codes: [ "02144" ]
    )
    assert_empty FindClientOrganizationDuplicates.call(
      agency: @agency, actor: @admin, names: { display_name: "Unrelated Org" }, postal_codes: [ "02144" ]
    )

    postal_hits = FindClientOrganizationDuplicates.call(
      agency: @agency, actor: @admin, names: { display_name: "Named Postal Org" }, postal_codes: [ "02144" ]
    )
    assert_equal [ owner.id ], postal_hits.map(&:id)
    assert_includes postal_hits.first.signals, "name_and_postal_code"

    locality_hits = FindClientOrganizationDuplicates.call(
      agency: @agency, actor: @admin, names: { display_name: "Named Postal Org" }, localities: [ "Somerville" ]
    )
    assert_equal [ owner.id ], locality_hits.map(&:id)
    assert_includes locality_hits.first.signals, "name_and_locality"
  end

  test "organization contact point audits include contact point identity and changed fields" do
    organization = create_organization("Audit Point Org")
    email = CreateClientOrganizationEmailAddress.new(
      agency: @agency, actor: @admin, client_organization: organization, attributes: { address: "audit@example.com" }
    ).call.record
    audit = AuditEvent.where(action: "client_organization.contact_updated", subject_id: organization.id).order(:created_at).last

    assert_equal email.id, audit.details["contact_point_id"]
    assert_equal "ClientOrganizationEmailAddress", audit.details["contact_point_type"]
    assert_equal [ "email_address" ], audit.details["changed_fields"]
  end

  test "organization mutations reject an actor or organization from another agency" do
    organization = create_organization("Harbor Mutation Org")
    other_org = CreateClientOrganization.new(
      agency: @other, actor: agency_users(:cove_admin), names: { display_name: "Cove Mutation Org" }
    ).call.record
    person = @agency.client_people.create!(first_name: "Harbor", last_name: "Contact")
    audits = AuditEvent.count

    assert_raises_with_code(:unauthorized) do
      AddClientOrganizationContact.new(
        agency: @other, actor: @admin, client_organization: organization, client_person: person,
        attributes: { starts_on: Date.new(2026, 1, 1) }
      ).call
    end
    assert_raises_with_code(:unauthorized) do
      CreateClientOrganizationEmailAddress.new(
        agency: @other, actor: @admin, client_organization: organization, attributes: { address: "x@example.com" }
      ).call
    end

    error = assert_raises(AgencyCommand::Error) do
      AddClientOrganizationContact.new(
        agency: @agency, actor: @admin, client_organization: other_org, client_person: person,
        attributes: { starts_on: Date.new(2026, 1, 1) }
      ).call
    end
    assert_includes %i[unauthorized invalid], error.code

    error = assert_raises(AgencyCommand::Error) do
      CreateClientOrganizationEmailAddress.new(
        agency: @agency, actor: @admin, client_organization: other_org, attributes: { address: "x@example.com" }
      ).call
    end
    assert_includes %i[unauthorized invalid], error.code
    assert_equal audits, AuditEvent.count
  end

  test "organization name search uses a display name or name vector index" do
    create_organization("Indexed Org Name")
    plan = nil
    ClientOrganization.transaction do
      ClientOrganization.connection.execute("SET LOCAL enable_seqscan = off")
      plan = ClientOrganization.where(agency_id: @agency.id, display_name_search_key: "indexed org name").explain.inspect
      raise ActiveRecord::Rollback
    end

    assert_match(/Index Scan|Bitmap Index Scan|Bitmap Heap Scan/, plan)
    assert_match(/display_name_search_key|name_search_vector/, plan)
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

  def create_organization(display_name, legal_name: nil)
    names = { display_name: display_name }
    names[:legal_name] = legal_name if legal_name
    CreateClientOrganization.new(agency: @agency, actor: @admin, names: names).call.record
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

  def search_ids(query, actor: @admin, kind: "organizations")
    SearchClientDirectory.call(agency: @agency, actor: actor, query: query, kind: kind).records.map(&:id)
  end

  def assert_organization_contact_acknowledgement(command:, organization:, attributes:, candidate:, signal:, signals: nil)
    error = assert_raises(AgencyCommand::DuplicateReviewRequired) do
      command.new(agency: @agency, actor: @admin, client_organization: organization, attributes: attributes).call
    end
    created = command.new(
      agency: @agency, actor: @admin, client_organization: organization, attributes: attributes,
      acknowledgement_token: error.token, acknowledgement_reason: "shared_contact"
    ).call
    replayed = command.new(
      agency: @agency, actor: @admin, client_organization: organization, attributes: attributes,
      acknowledgement_token: error.token, acknowledgement_reason: "shared_contact"
    ).call
    override = AuditEvent.where(action: "client_organization.duplicate_override", subject_id: organization.id).order(:created_at).last

    assert_equal :created, created.status
    assert_equal :replayed, replayed.status
    assert_equal created.record, replayed.record
    assert_equal [ candidate.id ], override.details["candidate_ids"]
    assert_equal (signals || [ signal ]), override.details["signals"]
    assert_equal "shared_contact", override.details["reason_code"]
    assert_not override.details.to_json.include?(candidate.display_name)
  end

  def assert_raises_with_code(code, &block)
    error = assert_raises(AgencyCommand::Error, &block)
    assert_equal code, error.code
  end
end
