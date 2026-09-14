require "test_helper"

class IndividualClientConstraintsTest < ActiveSupport::TestCase
  setup do
    @agency = agencies(:harbor)
    @person = @agency.client_people.create!(first_name: "Constraint", last_name: "Person")
  end

  test "directory tables omit office and use timestamptz" do
    %w[client_people clients client_person_email_addresses client_person_phone_numbers client_person_postal_addresses reference_sequences].each do |table|
      assert_not ClientPerson.connection.columns(table).map(&:name).include?("office_id"), table
    end
    assert_equal :datetime, ClientPerson.columns_hash["created_at"].type
    assert_match(/\A[0-9a-f-]{36}\z/, @person.id)
  end

  test "a cross-agency client pairing is rejected" do
    other_person = agencies(:cove).client_people.create!(first_name: "Other", last_name: "Person")

    assert_raises(ActiveRecord::InvalidForeignKey) do
      Client.insert!({
        id: SecureRandom.uuid_v7,
        agency_id: @agency.id,
        client_person_id: other_person.id,
        client_reference: "CL-000001",
        status: "active",
        lock_version: 0,
        created_at: Time.current,
        updated_at: Time.current
      })
    end
  end

  test "reference and tenant columns are immutable" do
    client = @agency.clients.create!(client_person: @person, client_reference: "CL-000009", status: "active")

    assert_raises(ActiveRecord::StatementInvalid) do
      Client.where(id: client.id).update_all(client_reference: "CL-000010")
    end
  end

  test "phone shape and country-only postal rows are rejected" do
    assert_raises(ActiveRecord::RecordInvalid) do
      @person.phone_numbers.create!(agency: @agency, number: "not-a-phone", normalized_number: "123", status: "active")
    end
    assert_raises(ActiveRecord::RecordInvalid) do
      @person.postal_addresses.create!(agency: @agency, country_code: "US", status: "active")
    end
    assert_raises(ActiveRecord::RecordInvalid) do
      @person.postal_addresses.create!(agency: @agency, line_1: "1 Dock", country_code: "XX", status: "active")
    end
  end

  test "preferred contact points are listed first" do
    later = @person.email_addresses.create!(agency: @agency, address: "later@example.com", preferred: false, status: "active")
    preferred = @person.email_addresses.create!(agency: @agency, address: "preferred@example.com", preferred: true, status: "active")

    assert_equal [ preferred, later ], @person.email_addresses.preferred_first.to_a
  end

  test "generated name search key folds without stripping accents" do
    person = @agency.client_people.create!(first_name: "José", last_name: "García")

    assert_equal "josé garcía", person.reload.name_search_key
  end
end
