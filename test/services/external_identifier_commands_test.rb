require "test_helper"

class ExternalIdentifierCommandsTest < ActiveSupport::TestCase
  test "adds deactivates and reactivates identifiers without copying values into audit" do
    party = parties(:unlinked)
    AddExternalIdentifier.new(
      agency: agencies(:one),
      actor: users(:one),
      party:,
      identifier_type: "legacy_party_id",
      original_value: "LEGACY-99"
    ).call
    identifier = party.external_identifiers.last
    event = agencies(:one).audit_events.where(action: "directory.external_identifier_created").order(:created_at).last
    assert_equal "legacy_party_id", event.details["identifier_type"]
    assert_not_includes event.details.to_s, "LEGACY-99"

    DeactivateExternalIdentifier.new(
      agency: agencies(:one),
      actor: users(:one),
      party:,
      identifier:,
      reason: "Wrong number"
    ).call
    assert identifier.reload.inactive?

    replacement = AddExternalIdentifier.new(
      agency: agencies(:one),
      actor: users(:one),
      party:,
      identifier_type: "legacy_party_id",
      original_value: "LEGACY-100"
    ).call
    assert replacement.ok?
    ReactivateExternalIdentifier.new(
      agency: agencies(:one),
      actor: users(:one),
      party:,
      identifier:
    ).call
    assert identifier.reload.active?
  end

  test "role identifiers require an active profile and leave inactive-role rows in history" do
    party = parties(:unlinked)
    profile = assign_client_role!(party, actor: users(:one))
    AddExternalIdentifier.new(
      agency: agencies(:one),
      actor: users(:one),
      party:,
      identifier_type: "external_crm_id",
      issuer: "Salesforce",
      original_value: "003xx"
    ).call
    identifier = profile.external_identifiers.last
    assert identifier.current_for_role?

    DeactivateClientProfile.new(
      agency: agencies(:one),
      actor: users(:one),
      party:,
      profile:,
      reason: "Paused"
    ).call
    assert_not identifier.reload.current_for_role?

    error = assert_raises(MembershipCommand::Error) do
      AddExternalIdentifier.new(
        agency: agencies(:one),
        actor: users(:one),
        party:,
        identifier_type: "legacy_client_id",
        issuer: "AMS",
        original_value: "C-2"
      ).call
    end
    assert_equal :invalid, error.code
  end

  test "reactivating a colliding contractual value is a conflict" do
    party = parties(:unlinked)
    assign_client_role!(party, actor: users(:one))
    first = AddExternalIdentifier.new(
      agency: agencies(:one),
      actor: users(:one),
      party:,
      identifier_type: "legacy_client_id",
      issuer: "AMS",
      original_value: "C-100"
    ).call.then { party.client_profile.external_identifiers.order(:created_at).last }
    DeactivateExternalIdentifier.new(
      agency: agencies(:one),
      actor: users(:one),
      party:,
      identifier: first,
      reason: "Replaced"
    ).call
    AddExternalIdentifier.new(
      agency: agencies(:one),
      actor: users(:one),
      party:,
      identifier_type: "legacy_client_id",
      issuer: "AMS",
      original_value: "C-100"
    ).call

    error = assert_raises(MembershipCommand::Error) do
      ReactivateExternalIdentifier.new(
        agency: agencies(:one),
        actor: users(:one),
        party:,
        identifier: first
      ).call
    end
    assert_equal :conflict, error.code
    assert first.reload.inactive?
  end

  test "missing issuer is rejected for per-issuer types" do
    assign_supplier_role!(parties(:organization_one), actor: users(:one))

    error = assert_raises(MembershipCommand::Error) do
      AddExternalIdentifier.new(
        agency: agencies(:one),
        actor: users(:one),
        party: parties(:organization_one),
        identifier_type: "supplier_account_number",
        original_value: "ACC-1"
      ).call
    end
    assert_equal :invalid, error.code
  end
end
