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

  private

  def create_client(actor: @admin, **names)
    CreateIndividualClient.new(agency: @agency, actor: actor, names: names).call
  end
end
