require "test_helper"

class RoleProfileCommandsTest < ActiveSupport::TestCase
  test "adds a client role to each party kind" do
    person = CreateClientProfile.new(
      agency: agencies(:one),
      actor: users(:one),
      party: parties(:unlinked),
      office: offices(:one)
    ).call.client_profile
    household = CreateClientProfile.new(
      agency: agencies(:one),
      actor: users(:one),
      party: parties(:household_one),
      office: offices(:one)
    ).call.client_profile
    organization = CreateClientProfile.new(
      agency: agencies(:one),
      actor: users(:one),
      party: parties(:organization_one),
      office: offices(:one)
    ).call.client_profile

    assert person.active?
    assert_equal "person", person.party_kind
    assert_equal offices(:one).id, person.responsible_office_id
    assert_equal "active", person.responsible_office_status
    assert_equal "active", person.party_status
    assert household.active?
    assert_equal "household", household.party_kind
    assert organization.active?
    assert_equal "organization", organization.party_kind
    assert_equal parties(:unlinked).status, parties(:unlinked).reload.status
    assert_includes agencies(:one).audit_events.pluck(:action), "directory.client_profile_created"
  end

  test "adds a supplier role to a person and an organization and copies agency currency" do
    person = CreateSupplierProfile.new(
      agency: agencies(:one),
      actor: users(:one),
      party: parties(:unlinked),
      office: offices(:one)
    ).call.supplier_profile
    organization = CreateSupplierProfile.new(
      agency: agencies(:one),
      actor: users(:one),
      party: parties(:organization_one),
      office: offices(:one)
    ).call.supplier_profile

    assert person.active?
    assert_equal "USD", person.default_currency
    assert_equal "person", person.party_kind
    assert organization.active?
    assert_equal "USD", organization.default_currency
    assert_includes agencies(:one).audit_events.pluck(:action), "directory.supplier_profile_created"
  end

  test "rejects a household supplier" do
    error = assert_raises(MembershipCommand::Error) do
      CreateSupplierProfile.new(
        agency: agencies(:one),
        actor: users(:one),
        party: parties(:household_one),
        office: offices(:one)
      ).call
    end

    assert_equal :invalid, error.code
    assert_match(/households cannot be suppliers/i, error.message)
    assert_nil parties(:household_one).reload.supplier_profile
  end

  test "staff can add a client role" do
    result = CreateClientProfile.new(
      agency: agencies(:two),
      actor: users(:two),
      party: parties(:two),
      office: offices(:two)
    ).call

    assert result.ok?
    assert result.client_profile.active?
  end

  test "deactivating and reactivating keep the same profile row and party status" do
    party = parties(:unlinked)
    profile = assign_client_role!(party, actor: users(:one))
    profile_id = profile.id
    party_status = party.status

    DeactivateClientProfile.new(
      agency: agencies(:one),
      actor: users(:one),
      party:,
      profile:,
      reason: "No longer purchasing"
    ).call
    profile.reload
    assert profile.inactive?
    assert_nil profile.responsible_office_status
    assert_nil profile.party_status
    assert_equal offices(:one).id, profile.responsible_office_id
    assert_equal party_status, party.reload.status

    extra = create_extra_office
    ReactivateClientProfile.new(
      agency: agencies(:one),
      actor: users(:one),
      party:,
      profile:,
      office: extra
    ).call
    profile.reload
    assert profile.active?
    assert_equal profile_id, profile.id
    assert_equal extra.id, profile.responsible_office_id
    assert_equal "active", profile.responsible_office_status
    assert_equal "active", profile.party_status
    assert_equal party_status, party.reload.status
    assert_includes agencies(:one).audit_events.pluck(:action), "directory.client_profile_deactivated"
    assert_includes agencies(:one).audit_events.pluck(:action), "directory.client_profile_reactivated"
  end

  test "creating a role when an inactive profile exists returns a reactivation conflict" do
    party = parties(:unlinked)
    profile = assign_client_role!(party, actor: users(:one))
    DeactivateClientProfile.new(
      agency: agencies(:one),
      actor: users(:one),
      party:,
      profile:,
      reason: "Paused"
    ).call

    error = assert_raises(MembershipCommand::Error) do
      CreateClientProfile.new(
        agency: agencies(:one),
        actor: users(:one),
        party:,
        office: offices(:one)
      ).call
    end

    assert_equal :reactivate, error.code
    assert_equal 1, ClientProfile.where(party_id: party.id).count
  end

  test "an inactive party cannot receive an active role" do
    party = parties(:unlinked)
    party.update!(
      status: "deactivated",
      deactivated_at: Time.current,
      deactivated_by_membership: agency_memberships(:one),
      deactivation_reason: "Left directory"
    )

    error = assert_raises(MembershipCommand::Error) do
      CreateClientProfile.new(
        agency: agencies(:one),
        actor: users(:one),
        party:,
        office: offices(:one)
      ).call
    end

    assert_equal :invalid, error.code
    assert_nil party.reload.client_profile
  end

  test "changing office locks both offices and does not accept status" do
    party = parties(:unlinked)
    profile = assign_client_role!(party, actor: users(:one))
    extra = create_extra_office

    UpdateClientProfile.new(
      agency: agencies(:one),
      actor: users(:one),
      party:,
      profile:,
      office: extra,
      lock_version: profile.lock_version
    ).call

    profile.reload
    assert profile.active?
    assert_equal extra.id, profile.responsible_office_id
    assert_equal "active", profile.responsible_office_status
    assert_includes agencies(:one).audit_events.pluck(:action), "directory.client_profile_updated"
  end

  test "rejects a stale lock_version" do
    party = parties(:unlinked)
    profile = assign_client_role!(party, actor: users(:one))

    error = assert_raises(MembershipCommand::Error) do
      DeactivateClientProfile.new(
        agency: agencies(:one),
        actor: users(:one),
        party:,
        profile:,
        reason: "Stale",
        lock_version: profile.lock_version - 1
      ).call
    end

    assert_equal :conflict, error.code
    assert profile.reload.active?
  end

  test "reactivation requires a currently active office" do
    party = parties(:unlinked)
    profile = assign_client_role!(party, actor: users(:one))
    extra = create_extra_office
    DeactivateClientProfile.new(
      agency: agencies(:one),
      actor: users(:one),
      party:,
      profile:,
      reason: "Paused"
    ).call
    ChangeOfficeStatus.new(
      agency: agencies(:one),
      actor: users(:one),
      office: extra,
      to: "inactive",
      reason: "Seasonal"
    ).call

    error = assert_raises(MembershipCommand::Error) do
      ReactivateClientProfile.new(
        agency: agencies(:one),
        actor: users(:one),
        party:,
        profile: profile.reload,
        office: extra
      ).call
    end

    assert_equal :invalid, error.code
    assert profile.reload.inactive?
  end

  test "deactivating an office is blocked while an active profile uses it" do
    assign_client_role!(parties(:unlinked), actor: users(:one), office: offices(:one))
    create_extra_office

    error = assert_raises(MembershipCommand::Error) do
      ChangeOfficeStatus.new(
        agency: agencies(:one),
        actor: users(:one),
        office: offices(:one),
        to: "inactive",
        reason: "Seasonal close"
      ).call
    end

    assert_equal :role_dependency, error.code
    assert_match(/Alex Morgan \(client\)/, error.message)
    assert offices(:one).reload.active?
  end

  test "office deactivation names a bounded sample of dependent roles" do
    extra = create_extra_office
    [
      parties(:unlinked),
      parties(:organization_one),
      parties(:household_one),
      parties(:maria),
      parties(:harbor_hotel),
      parties(:harbor_group)
    ].each do |party|
      assign_client_role!(party, actor: users(:one), office: extra)
    end

    error = assert_raises(MembershipCommand::Error) do
      ChangeOfficeStatus.new(
        agency: agencies(:one),
        actor: users(:one),
        office: extra,
        to: "inactive",
        reason: "Seasonal close"
      ).call
    end

    assert_equal :role_dependency, error.code
    assert_match(/\AReassign 6 active roles before deactivating this office: /, error.message)
    assert_includes error.message, "Alex Morgan (client)"
    assert_includes error.message, "Horizon Tours (client)"
    assert_includes error.message, "Morgan Household (client)"
    assert_includes error.message, "Maria Ruiz (client)"
    assert_includes error.message, "Harbor Hotel Boston (client)"
    assert_not_includes error.message, "Harbor Hospitality Group"
    assert_match(/, and 1 more\.\z/, error.message)
    assert extra.reload.active?
  end

  test "an administrator from another agency cannot mutate roles" do
    error = assert_raises(MembershipCommand::Error) do
      CreateClientProfile.new(
        agency: agencies(:one),
        actor: users(:two),
        party: parties(:unlinked),
        office: offices(:one)
      ).call
    end

    assert_equal :unauthorized, error.code
  end

  private

  def create_extra_office(code: "BOS")
    CreateOffice.new(
      agency: agencies(:one),
      actor: users(:one),
      name: "Boston",
      code:,
      default_timezone: agencies(:one).default_timezone
    ).call.office
  end
end
