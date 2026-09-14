require "test_helper"

class ClientOrganizationConstraintsTest < ActiveSupport::TestCase
  setup do
    @agency = agencies(:harbor)
    @other = agencies(:cove)
    @organization = @agency.client_organizations.create!(display_name: "Harbor Tours", status: "active")
    @person = @agency.client_people.create!(first_name: "Ada", last_name: "Contact")
    @other_person = @other.client_people.create!(first_name: "Other", last_name: "Person")
    @other_organization = @other.client_organizations.create!(display_name: "Cove Tours", status: "active")
  end

  test "organization tables omit office_id" do
    %w[
      client_organizations
      client_organization_email_addresses
      client_organization_phone_numbers
      client_organization_postal_addresses
      client_organization_websites
      client_organization_contacts
    ].each do |table|
      assert_not ClientOrganization.connection.columns(table).map(&:name).include?("office_id"), table
    end
  end

  test "existing person-backed clients remain valid and xor ownership is enforced" do
    person = @agency.client_people.create!(first_name: "Pat", last_name: "Person")
    client = @agency.clients.create!(client_person: person, client_reference: "CL-000101", status: "active")

    assert_nil client.client_organization_id
    assert_equal person.id, client.client_person_id

    assert_raises(ActiveRecord::StatementInvalid) do
      Client.insert!({
        id: SecureRandom.uuid_v7,
        agency_id: @agency.id,
        client_person_id: nil,
        client_organization_id: nil,
        client_reference: "CL-000102",
        status: "active",
        lock_version: 0,
        created_at: Time.current,
        updated_at: Time.current
      })
    end

    assert_raises(ActiveRecord::StatementInvalid) do
      Client.insert!({
        id: SecureRandom.uuid_v7,
        agency_id: @agency.id,
        client_person_id: person.id,
        client_organization_id: @organization.id,
        client_reference: "CL-000103",
        status: "active",
        lock_version: 0,
        created_at: Time.current,
        updated_at: Time.current
      })
    end
  end

  test "person unique index remains null-distinct and organization source is partially unique" do
    first = @agency.clients.create!(client_organization: @organization, client_reference: "CL-000201", status: "active")
    second_org = @agency.client_organizations.create!(display_name: "Second Org", status: "active")
    second = @agency.clients.create!(client_organization: second_org, client_reference: "CL-000202", status: "active")

    assert_nil first.client_person_id
    assert_nil second.client_person_id

    assert_raises(ActiveRecord::RecordNotUnique) do
      Client.insert!({
        id: SecureRandom.uuid_v7,
        agency_id: @agency.id,
        client_person_id: nil,
        client_organization_id: @organization.id,
        client_reference: "CL-000203",
        status: "inactive",
        lock_version: 0,
        created_at: Time.current,
        updated_at: Time.current
      })
    end
  end

  test "client source ids and organization ownership are immutable" do
    client = @agency.clients.create!(client_organization: @organization, client_reference: "CL-000301", status: "active")
    other_org = @agency.client_organizations.create!(display_name: "Move Target", status: "active")

    assert_raises(ActiveRecord::StatementInvalid) do
      ClientOrganization.transaction(requires_new: true) do
        ClientOrganization.where(id: @organization.id).update_all(agency_id: @other.id)
      end
    end

    assert_raises(ActiveRecord::StatementInvalid) do
      Client.transaction(requires_new: true) do
        Client.where(id: client.id).update_all(client_organization_id: other_org.id, client_person_id: nil)
      end
    end

    assert_raises(ActiveRecord::StatementInvalid) do
      Client.transaction(requires_new: true) do
        Client.where(id: client.id).update_all(client_organization_id: nil, client_person_id: @person.id)
      end
    end
  end

  test "same-agency foreign keys reject cross-agency pairings" do
    assert_raises(ActiveRecord::InvalidForeignKey) do
      Client.transaction(requires_new: true) do
        Client.insert!({
          id: SecureRandom.uuid_v7,
          agency_id: @agency.id,
          client_person_id: nil,
          client_organization_id: @other_organization.id,
          client_reference: "CL-000401",
          status: "active",
          lock_version: 0,
          created_at: Time.current,
          updated_at: Time.current
        })
      end
    end

    assert_raises(ActiveRecord::InvalidForeignKey) do
      ClientOrganizationContact.transaction(requires_new: true) do
        ClientOrganizationContact.insert!({
          id: SecureRandom.uuid_v7,
          agency_id: @agency.id,
          client_organization_id: @organization.id,
          client_person_id: @other_person.id,
          starts_on: Date.new(2026, 1, 1),
          ends_on: nil,
          primary: false,
          lock_version: 0,
          created_at: Time.current,
          updated_at: Time.current
        })
      end
    end
  end

  test "current means ends_on is null and only one current primary exists" do
    current = insert_contact!(@person, starts_on: Date.new(2026, 1, 1), ends_on: nil, primary: true)
    assert_predicate current, :current?
    assert_includes ClientOrganizationContact.current, current

    other_person = @agency.client_people.create!(first_name: "Bea", last_name: "Second")
    assert_raises(ActiveRecord::RecordNotUnique) do
      insert_contact!(other_person, starts_on: Date.new(2026, 1, 1), ends_on: nil, primary: true)
    end
  end

  test "overlapping periods for the same pair are rejected while different pairs and adjacent dates are accepted" do
    insert_contact!(@person, starts_on: Date.new(2026, 1, 1), ends_on: Date.new(2026, 1, 31), primary: false)

    assert_raises(ActiveRecord::StatementInvalid) do
      insert_contact!(@person, starts_on: Date.new(2026, 1, 15), ends_on: Date.new(2026, 2, 15), primary: false)
    end

    insert_contact!(@person, starts_on: Date.new(2026, 2, 1), ends_on: Date.new(2026, 2, 28), primary: false)

    other_person = @agency.client_people.create!(first_name: "Cal", last_name: "Other")
    insert_contact!(other_person, starts_on: Date.new(2026, 1, 10), ends_on: Date.new(2026, 1, 20), primary: false)
  end

  test "same-day restart after an end is rejected and next-day restart is accepted" do
    insert_contact!(@person, starts_on: Date.new(2026, 1, 1), ends_on: Date.new(2026, 3, 14), primary: false)

    assert_raises(ActiveRecord::StatementInvalid) do
      insert_contact!(@person, starts_on: Date.new(2026, 3, 14), ends_on: nil, primary: false)
    end

    insert_contact!(@person, starts_on: Date.new(2026, 3, 15), ends_on: nil, primary: false)
  end

  test "btree_gist exists only for the named organization-contact exclusion" do
    enabled = ActiveRecord::Base.connection.select_value(<<~SQL)
      SELECT count(*) FROM pg_extension WHERE extname = 'btree_gist'
    SQL
    assert_equal 1, enabled.to_i

    exclusions = ActiveRecord::Base.connection.select_values(<<~SQL)
      SELECT c.conname
      FROM pg_constraint c
      JOIN pg_class t ON t.oid = c.conrelid
      WHERE c.contype = 'x'
      ORDER BY c.conname
    SQL
    assert_equal [ "client_org_contacts_no_overlapping_history" ], exclusions
  end

  private

  def insert_contact!(person, starts_on:, ends_on:, primary:)
    ClientOrganizationContact.create!(
      agency: @agency,
      client_organization: @organization,
      client_person: person,
      starts_on: starts_on,
      ends_on: ends_on,
      primary: primary
    )
  end
end
