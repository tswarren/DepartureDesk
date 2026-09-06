require "test_helper"

class ExternalIdentifierTest < ActiveSupport::TestCase
  test "ruby registry type codes match the sql type owner constraint" do
    definition = ExternalIdentifier.connection.select_value(<<~SQL.squish)
      SELECT pg_get_constraintdef(oid)
      FROM pg_constraint
      WHERE conname = 'external_identifiers_type_owner'
    SQL
    sql_types = definition.scan(/'([a-z_]+)'/).flatten.uniq.sort

    assert_equal ExternalIdentifierRegistry.codes.sort, sql_types
  end

  test "exactly one owner is required and office_id must be null" do
    now = Time.current
    party = parties(:unlinked)

    assert_raises(ActiveRecord::StatementInvalid) do
      ExternalIdentifier.transaction(requires_new: true) do
        ExternalIdentifier.insert_all!([ identifier_row(party:, now:).merge(client_profile_id: SecureRandom.uuid) ])
      end
    end

    assert_raises(ActiveRecord::StatementInvalid) do
      ExternalIdentifier.transaction(requires_new: true) do
        ExternalIdentifier.insert_all!([ identifier_row(party:, now:).merge(office_id: offices(:one).id) ])
      end
    end
  end

  test "client identifier types cannot attach to a party owner" do
    now = Time.current

    assert_raises(ActiveRecord::StatementInvalid) do
      ExternalIdentifier.transaction(requires_new: true) do
        ExternalIdentifier.insert_all!([
          identifier_row(party: parties(:unlinked), now:).merge(
            identifier_type: "legacy_client_id",
            issuer: "legacy"
          )
        ])
      end
    end
  end

  test "contractually unique identifiers collide per issuer within an agency" do
    profile = assign_client_role!(parties(:unlinked), actor: users(:one))
    AddExternalIdentifier.new(
      agency: agencies(:one),
      actor: users(:one),
      party: parties(:unlinked),
      identifier_type: "legacy_client_id",
      issuer: "AMS",
      original_value: "C-100"
    ).call

    error = assert_raises(MembershipCommand::Error) do
      AddExternalIdentifier.new(
        agency: agencies(:one),
        actor: users(:one),
        party: parties(:unlinked),
        identifier_type: "legacy_client_id",
        issuer: "AMS",
        original_value: "C-100"
      ).call
    end
    assert_equal :conflict, error.code
    assert_equal 1, ExternalIdentifier.where(client_profile: profile, identifier_type: "legacy_client_id").count
  end

  test "identity fields cannot change after create" do
    identifier = AddExternalIdentifier.new(
      agency: agencies(:one),
      actor: users(:one),
      party: parties(:unlinked),
      identifier_type: "legacy_party_id",
      original_value: "P-1"
    ).call.then { parties(:unlinked).external_identifiers.last }

    assert_raises(ActiveRecord::StatementInvalid) do
      ExternalIdentifier.transaction(requires_new: true) do
        ExternalIdentifier.connection.execute(
          "UPDATE external_identifiers SET original_value = 'P-2' WHERE id = '#{identifier.id}'"
        )
      end
    end
  end

  private

  def identifier_row(party:, now:)
    {
      agency_id: party.agency_id,
      party_id: party.id,
      identifier_type: "legacy_party_id",
      original_value: "P-1",
      normalized_value: "P-1",
      normalization_version: 1,
      status: "active",
      source: "staff",
      lock_version: 0,
      created_at: now,
      updated_at: now
    }
  end
end
