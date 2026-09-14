require "test_helper"

class IndividualClientDirectoryTest < ActiveSupport::TestCase
  setup do
    @agency = agencies(:harbor)
    @other = agencies(:cove)
    @admin = agency_users(:harbor_admin)
    @staff = agency_users(:harbor_staff)
    @viewer = agency_users(:harbor_viewer)
  end

  test "creates an individual client and issues the next reference" do
    result = create_client(first_name: "Ada", last_name: "Lovelace")

    assert_equal "CL-000001", result.record.client_reference
    assert_equal 2, reference_sequences(:harbor_client).reload.next_value
    assert_equal %w[client.created client_person.created].sort, AuditEvent.where(agency: @agency, subject_id: [ result.record.id, result.record.client_person_id ]).pluck(:action).sort
  end

  test "a missing sequence row is not created by issuance" do
    reference_sequences(:harbor_client).delete

    error = assert_raises(AgencyCommand::Error) { create_client(first_name: "Ada", last_name: "Lovelace") }
    assert_equal :invalid, error.code
    assert_equal 0, @agency.clients.count
    assert_equal 0, ReferenceSequence.where(agency: @agency, namespace: "client").count
  end

  test "issuing 1000000 is rejected" do
    reference_sequences(:harbor_client).update!(next_value: 1_000_000)

    error = assert_raises(AgencyCommand::Error) { create_client(first_name: "Ada", last_name: "Lovelace") }
    assert_equal :reference_exhausted, error.code
    assert_equal 0, @agency.clients.count
  end

  test "composite create rolls back when duplicate review is required" do
    create_client(first_name: "Ada", last_name: "Lovelace")

    assert_raises(AgencyCommand::DuplicateReviewRequired) { create_client(first_name: "Ada", last_name: "Lovelace") }
    assert_equal 1, @agency.clients.count
    assert_equal 1, @agency.client_people.count
  end

  test "create token replay does not issue another reference" do
    create_client(first_name: "Ada", last_name: "Lovelace")
    error = assert_raises(AgencyCommand::DuplicateReviewRequired) { create_client(first_name: "Ada", last_name: "Lovelace") }
    acknowledged = CreateIndividualClient.new(
      agency: @agency, actor: @admin, names: { first_name: "Ada", last_name: "Lovelace" },
      acknowledgement_token: error.token, acknowledgement_reason: "confirmed_distinct"
    ).call
    replayed = CreateIndividualClient.new(
      agency: @agency, actor: @admin, names: { first_name: "Ada", last_name: "Lovelace" },
      acknowledgement_token: error.token, acknowledgement_reason: "confirmed_distinct"
    ).call

    assert_equal :created, acknowledged.status
    assert_equal :replayed, replayed.status
    assert_equal acknowledged.record, replayed.record
    assert_equal 2, @agency.clients.count
    assert_equal 3, reference_sequences(:harbor_client).reload.next_value
  end

  test "a partial composite replay is a conflict" do
    create_client(first_name: "Ada", last_name: "Lovelace")
    error = assert_raises(AgencyCommand::DuplicateReviewRequired) { create_client(first_name: "Ada", last_name: "Lovelace") }
    payload = DuplicateAcknowledgement.verify!(error.token, agency: @agency, actor: @admin, command: "CreateIndividualClient")
    @agency.client_people.create!(id: payload.fetch("person_id"), first_name: "Ada", last_name: "Lovelace")

    conflict = assert_raises(AgencyCommand::Error) do
      CreateIndividualClient.new(
        agency: @agency, actor: @admin, names: { first_name: "Ada", last_name: "Lovelace" },
        acknowledgement_token: error.token, acknowledgement_reason: "confirmed_distinct"
      ).call
    end
    assert_equal :conflict, conflict.code
    assert_equal 1, @agency.clients.count
  end

  test "viewer cannot mutate and sees no email-only match" do
    person = CreateClientPerson.new(agency: @agency, actor: @admin, names: { first_name: "Hidden", last_name: "Mail" }).call.record
    CreateClientPersonEmailAddress.new(agency: @agency, actor: @admin, client_person: person, attributes: { address: "hidden@example.com" }).call

    error = assert_raises(AgencyCommand::Error) { create_client(actor: @viewer, first_name: "Nope", last_name: "Nope") }
    assert_equal :unauthorized, error.code
    assert_equal 0, AuditEvent.where(action: "client.created").count

    result = SearchClientDirectory.call(agency: @agency, actor: @viewer, query: "hidden@example.com")
    assert_empty result.records
  end

  test "staff can search an email and a viewer can search a name" do
    person = CreateClientPerson.new(agency: @agency, actor: @staff, names: { first_name: "José", last_name: "García" }).call.record
    CreateClientPersonEmailAddress.new(agency: @agency, actor: @staff, client_person: person, attributes: { address: "jose@example.com" }).call

    staff_match = SearchClientDirectory.call(agency: @agency, actor: @staff, query: "jose@example.com")
    viewer_match = SearchClientDirectory.call(agency: @agency, actor: @viewer, query: "José Gar")

    assert_equal [ person.id ], staff_match.records.map(&:id)
    assert_equal [ person.id ], viewer_match.records.map(&:id)
    assert_empty SearchClientDirectory.call(agency: @agency, actor: @viewer, query: "Jose Gar").records
  end

  test "search does not cross agencies" do
    CreateClientPerson.new(agency: @other, actor: agency_users(:cove_admin), names: { first_name: "Cove", last_name: "Only" }).call

    assert_empty SearchClientDirectory.call(agency: @agency, actor: @admin, query: "Cove Only").records
  end

  test "person inactivation cascades contacts and does not restore them" do
    person = CreateClientPerson.new(agency: @agency, actor: @admin, names: { first_name: "Inactive", last_name: "Next" }).call.record
    email = CreateClientPersonEmailAddress.new(
      agency: @agency, actor: @admin, client_person: person, attributes: { address: "next@example.com", preferred: true }
    ).call.record

    ChangeClientPersonStatus.new(agency: @agency, actor: @admin, client_person: person, status: "inactive", lock_version: person.lock_version).call
    assert_equal "inactive", email.reload.status
    assert_not email.preferred?

    ChangeClientPersonStatus.new(agency: @agency, actor: @admin, client_person: person, status: "active", lock_version: person.reload.lock_version).call
    assert_equal "inactive", email.reload.status
  end

  test "an active client blocks person inactivation and an inactive person blocks client reactivation" do
    client = create_client(first_name: "Busy", last_name: "Client").record
    person = client.client_person

    error = assert_raises(AgencyCommand::Error) do
      ChangeClientPersonStatus.new(agency: @agency, actor: @admin, client_person: person, status: "inactive", lock_version: person.lock_version).call
    end
    assert_equal :dependency_exists, error.code

    ChangeClientStatus.new(agency: @agency, actor: @admin, client: client, status: "inactive", lock_version: client.lock_version).call
    ChangeClientPersonStatus.new(agency: @agency, actor: @admin, client_person: person, status: "inactive", lock_version: person.reload.lock_version).call
    error = assert_raises(AgencyCommand::Error) do
      ChangeClientStatus.new(agency: @agency, actor: @admin, client: client.reload, status: "active", lock_version: client.lock_version).call
    end
    assert_equal :dependency_exists, error.code
  end

  test "preferred can be set or cleared without changing the destination" do
    person = CreateClientPerson.new(agency: @agency, actor: @admin, names: { first_name: "Pref", last_name: "Switch" }).call.record
    first = CreateClientPersonEmailAddress.new(
      agency: @agency, actor: @admin, client_person: person, attributes: { address: "first@example.com", preferred: true }
    ).call.record
    second = CreateClientPersonEmailAddress.new(
      agency: @agency, actor: @admin, client_person: person, attributes: { address: "second@example.com" }
    ).call.record

    UpdateClientPersonEmailAddress.new(
      agency: @agency, actor: @admin, client_person: person, record: second,
      attributes: { address: second.address, preferred: "1" }, lock_version: second.lock_version
    ).call
    assert second.reload.preferred?
    assert_not first.reload.preferred?

    UpdateClientPersonEmailAddress.new(
      agency: @agency, actor: @admin, client_person: person, record: first,
      attributes: { address: first.address, preferred: "1" }, lock_version: first.lock_version
    ).call
    assert first.reload.preferred?
    assert_not second.reload.preferred?

    UpdateClientPersonEmailAddress.new(
      agency: @agency, actor: @admin, client_person: person, record: first,
      attributes: { address: first.address, preferred: "0" }, lock_version: first.lock_version
    ).call
    assert_not first.reload.preferred?
  end

  test "name search uses the stored key index" do
    create_client(first_name: "Indexed", last_name: "Name")
    plan = nil
    ClientPerson.transaction do
      ClientPerson.connection.execute("SET LOCAL enable_seqscan = off")
      plan = ClientPerson.where(agency_id: @agency.id, name_search_key: "indexed name").explain.inspect
      raise ActiveRecord::Rollback
    end

    assert_match(/Index Scan/, plan)
    assert_no_match(/Seq Scan/, plan)
    definition = ClientPerson.connection.select_value(<<~SQL)
      SELECT indexdef FROM pg_indexes
      WHERE indexname = 'index_client_people_on_agency_and_name_search_key'
    SQL
    assert_match(/agency_id, name_search_key/, definition)
  end

  test "acknowledged contact creates continue and replay for the signed person" do
    email_owner = CreateClientPerson.new(agency: @agency, actor: @admin, names: { first_name: "Mail", last_name: "Owner" }).call.record
    CreateClientPersonEmailAddress.new(agency: @agency, actor: @admin, client_person: email_owner, attributes: { address: "shared@example.com" }).call
    email_person = CreateClientPerson.new(agency: @agency, actor: @admin, names: { first_name: "Mail", last_name: "Other" }).call.record
    assert_contact_acknowledgement(
      command: CreateClientPersonEmailAddress,
      person: email_person,
      attributes: { address: "shared@example.com" },
      candidate: email_owner,
      signal: "exact_email"
    )

    phone_owner = CreateClientPerson.new(agency: @agency, actor: @admin, names: { first_name: "Phone", last_name: "Owner" }).call.record
    CreateClientPersonPhoneNumber.new(
      agency: @agency, actor: @admin, client_person: phone_owner,
      attributes: { number: "202-555-0100", country_code: "US" }
    ).call
    phone_person = CreateClientPerson.new(agency: @agency, actor: @admin, names: { first_name: "Phone", last_name: "Other" }).call.record
    assert_contact_acknowledgement(
      command: CreateClientPersonPhoneNumber,
      person: phone_person,
      attributes: { number: "202-555-0100", country_code: "US" },
      candidate: phone_owner,
      signal: "exact_phone"
    )

    postal_owner = CreateClientPerson.new(agency: @agency, actor: @admin, names: { first_name: "Ada", last_name: "Postal" }).call.record
    CreateClientPersonPostalAddress.new(
      agency: @agency, actor: @admin, client_person: postal_owner,
      attributes: { line_1: "1 Dock", postal_code: "02139", country_code: "US" }
    ).call
    name_review = assert_raises(AgencyCommand::DuplicateReviewRequired) do
      CreateClientPerson.new(agency: @agency, actor: @admin, names: { first_name: "Ada", last_name: "Postal" }).call
    end
    postal_person = CreateClientPerson.new(
      agency: @agency, actor: @admin, names: { first_name: "Ada", last_name: "Postal" },
      acknowledgement_token: name_review.token, acknowledgement_reason: "confirmed_distinct"
    ).call.record
    assert_contact_acknowledgement(
      command: CreateClientPersonPostalAddress,
      person: postal_person,
      attributes: { line_1: "2 Pier", postal_code: "02139", country_code: "US" },
      candidate: postal_owner,
      signal: "exact_full_name_and_postal_code",
      signals: %w[exact_full_name exact_full_name_and_postal_code]
    )
  end

  test "a contact acknowledgement is a conflict when the point belongs to another person" do
    owner = CreateClientPerson.new(agency: @agency, actor: @admin, names: { first_name: "Held", last_name: "Owner" }).call.record
    CreateClientPersonEmailAddress.new(agency: @agency, actor: @admin, client_person: owner, attributes: { address: "held@example.com" }).call
    person = CreateClientPerson.new(agency: @agency, actor: @admin, names: { first_name: "Held", last_name: "Other" }).call.record
    error = assert_raises(AgencyCommand::DuplicateReviewRequired) do
      CreateClientPersonEmailAddress.new(agency: @agency, actor: @admin, client_person: person, attributes: { address: "held@example.com" }).call
    end
    payload = DuplicateAcknowledgement.verify!(error.token, agency: @agency, actor: @admin, command: "CreateClientPersonEmailAddress")
    owner.email_addresses.create!(
      id: payload.fetch("contact_point_id"), agency: @agency, address: "elsewhere@example.com", status: "active"
    )

    conflict = assert_raises(AgencyCommand::Error) do
      CreateClientPersonEmailAddress.new(
        agency: @agency, actor: @admin, client_person: person, attributes: { address: "held@example.com" },
        acknowledgement_token: error.token, acknowledgement_reason: "shared_contact"
      ).call
    end
    assert_equal :conflict, conflict.code
    assert_equal 0, person.email_addresses.count
  end

  test "directory reads and writes reject an actor from another agency" do
    person = CreateClientPerson.new(agency: @agency, actor: @admin, names: { first_name: "Harbor", last_name: "Only" }).call.record
    email = CreateClientPersonEmailAddress.new(
      agency: @agency, actor: @admin, client_person: person, attributes: { address: "harbor@example.com" }
    ).call.record
    client = create_client(first_name: "Bound", last_name: "Client").record
    CreateClientPerson.new(agency: @other, actor: agency_users(:cove_admin), names: { first_name: "Cove", last_name: "Secret" }).call
    audits = AuditEvent.count

    [
      -> { SearchClientDirectory.call(agency: @other, actor: @admin, query: "Cove Secret") },
      -> { FindClientPersonDuplicates.call(agency: @other, actor: @admin, names: { first_name: "Cove", last_name: "Secret" }) },
      -> { CreateClientPerson.new(agency: @other, actor: @admin, names: { first_name: "Nope", last_name: "Nope" }).call },
      -> { CreateIndividualClient.new(agency: @other, actor: @admin, names: { first_name: "Nope", last_name: "Nope" }).call },
      -> { UpdateClientPerson.new(agency: @other, actor: @admin, client_person: person, names: { first_name: "Nope", last_name: "Nope" }, lock_version: person.lock_version).call },
      -> { ChangeClientPersonStatus.new(agency: @other, actor: @admin, client_person: person, status: "inactive", lock_version: person.lock_version).call },
      -> { ChangeClientStatus.new(agency: @other, actor: @admin, client: client, status: "inactive", lock_version: client.lock_version).call },
      -> { CreateClientForPerson.new(agency: @other, actor: @admin, client_person: person).call },
      -> { CreateClientPersonEmailAddress.new(agency: @other, actor: @admin, client_person: person, attributes: { address: "nope@example.com" }).call },
      -> { UpdateClientPersonEmailAddress.new(agency: @other, actor: @admin, client_person: person, record: email, attributes: { address: "changed@example.com" }, lock_version: email.lock_version).call },
      -> { ChangeClientPersonEmailAddressStatus.new(agency: @other, actor: @admin, client_person: person, record: email, status: "inactive", lock_version: email.lock_version).call }
    ].each do |attempt|
      error = assert_raises(AgencyCommand::Error, &attempt)
      assert_equal :unauthorized, error.code
      assert_equal AgencyCommand::UNAUTHORIZED, error.message
    end

    assert_equal audits, AuditEvent.count
    assert_equal "Cove", @other.client_people.pick(:first_name)
    assert_equal "active", person.reload.status
  end

  test "search caps ranked people in SQL" do
    51.times do |index|
      CreateClientPerson.new(agency: @agency, actor: @admin, names: { first_name: "Trunc", last_name: format("%03d", index) }).call
    end

    queries = []
    callback = ->(*, payload) { queries << payload[:sql] if payload[:sql].include?("search_rank") }
    result = ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
      SearchClientDirectory.call(agency: @agency, actor: @admin, query: "Trunc")
    end

    assert_equal 50, result.records.size
    assert result.truncated
    assert queries.any? { |sql| sql.match?(/LIMIT 51/i) }
  end

  test "set primary submits a lock version and does not audit an already preferred point" do
    person = CreateClientPerson.new(agency: @agency, actor: @admin, names: { first_name: "Primary", last_name: "Lock" }).call.record
    email = CreateClientPersonEmailAddress.new(
      agency: @agency, actor: @admin, client_person: person, attributes: { address: "lock@example.com" }
    ).call.record
    audits = AuditEvent.where(action: "client_person.contact_updated", subject_id: person.id).count

    updated = SetPreferredClientPersonEmailAddress.new(
      agency: @agency, actor: @admin, client_person: person, record: email, lock_version: email.lock_version
    ).call
    noop = SetPreferredClientPersonEmailAddress.new(
      agency: @agency, actor: @admin, client_person: person, record: email, lock_version: email.reload.lock_version
    ).call

    assert_equal :updated, updated.status
    assert_equal :noop, noop.status
    assert email.reload.preferred?
    assert_equal audits + 1, AuditEvent.where(action: "client_person.contact_updated", subject_id: person.id).count
  end

  private

  def create_client(actor: @admin, **names)
    CreateIndividualClient.new(agency: @agency, actor: actor, names: names).call
  end

  def assert_contact_acknowledgement(command:, person:, attributes:, candidate:, signal:, signals: nil)
    error = assert_raises(AgencyCommand::DuplicateReviewRequired) do
      command.new(agency: @agency, actor: @admin, client_person: person, attributes: attributes).call
    end
    created = command.new(
      agency: @agency, actor: @admin, client_person: person, attributes: attributes,
      acknowledgement_token: error.token, acknowledgement_reason: "shared_contact"
    ).call
    replayed = command.new(
      agency: @agency, actor: @admin, client_person: person, attributes: attributes,
      acknowledgement_token: error.token, acknowledgement_reason: "shared_contact"
    ).call
    override = AuditEvent.where(action: "client_person.duplicate_override", subject_id: person.id).order(:created_at).last

    assert_equal :created, created.status
    assert_equal :replayed, replayed.status
    assert_equal created.record, replayed.record
    assert_equal [ candidate.id ], override.details["candidate_ids"]
    assert_equal (signals || [ signal ]), override.details["signals"]
    assert_equal "shared_contact", override.details["reason_code"]
    assert_not override.details.to_json.include?(candidate.display_name)
  end
end
