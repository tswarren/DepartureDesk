require "test_helper"

class CreatePartyTest < ActiveSupport::TestCase
  test "creates each kind atomically with derived names and audit" do
    person = CreateParty.new(
      agency: agencies(:one),
      actor: users(:one),
      party_kind: "person",
      attributes: { given_name: "Jamie", middle_name: "Lee", family_name: "Cole", prefix: "Mx" }
    ).call.party
    household = CreateParty.new(
      agency: agencies(:one),
      actor: users(:one),
      party_kind: "household",
      attributes: { name: "Cole Household" }
    ).call.party
    organization = CreateParty.new(
      agency: agencies(:one),
      actor: users(:one),
      party_kind: "organization",
      attributes: { legal_name: "Summit Travel Co", trading_name: "Summit Travel" }
    ).call.party

    assert_equal "Jamie Lee Cole", person.display_name
    assert_equal "Cole, Jamie Lee", person.sort_name
    assert_equal person.id, person.person.party_id
    assert_equal "Cole Household", household.display_name
    assert_equal "Summit Travel", organization.display_name
    assert_includes agencies(:one).audit_events.pluck(:action), "directory.party_created"
  end

  test "staff can create a party" do
    result = CreateParty.new(
      agency: agencies(:two),
      actor: users(:two),
      party_kind: "person",
      attributes: { given_name: "Staff", family_name: "Created" }
    ).call

    assert result.ok?
    assert_equal "Staff Created", result.party.display_name
  end

  test "rolls back the party when the profile is invalid" do
    assert_no_difference(%w[Party.count Person.count AuditEvent.count]) do
      error = assert_raises(MembershipCommand::Error) do
        CreateParty.new(
          agency: agencies(:one),
          actor: users(:one),
          party_kind: "person",
          attributes: { given_name: "", family_name: "Cole" }
        ).call
      end
      assert_equal :invalid, error.code
    end
  end

  test "ignores submitted agency ownership" do
    result = CreateParty.new(
      agency: agencies(:one),
      actor: users(:one),
      party_kind: "person",
      attributes: { given_name: "Pat", family_name: "Lee", agency_id: agencies(:two).id }
    ).call

    assert_equal agencies(:one).id, result.party.agency_id
  end
end

class UpdatePartyTest < ActiveSupport::TestCase
  test "updates derived names and records audit without changing kind" do
    party = parties(:unlinked)

    UpdateParty.new(
      agency: agencies(:one),
      actor: users(:one),
      party: party,
      attributes: { preferred_name: "Al" },
      party_lock_version: party.lock_version,
      profile_lock_version: party.person.lock_version
    ).call

    assert_equal "Al Morgan", party.reload.display_name
    assert_equal "person", party.party_kind
    assert_includes agencies(:one).audit_events.pluck(:action), "directory.party_updated"
    assert_not_includes agencies(:one).audit_events.where(action: "directory.party_updated").last.details.to_s, "date_of_birth"
  end

  test "fails when the party lock_version is stale" do
    party = parties(:unlinked)

    error = assert_raises(MembershipCommand::Error) do
      UpdateParty.new(
        agency: agencies(:one),
        actor: users(:one),
        party: party,
        attributes: { preferred_name: "Al" },
        party_lock_version: party.lock_version - 1,
        profile_lock_version: party.person.lock_version
      ).call
    end

    assert_equal :conflict, error.code
  end

  test "fails when the profile lock_version is stale" do
    party = parties(:unlinked)

    error = assert_raises(MembershipCommand::Error) do
      UpdateParty.new(
        agency: agencies(:one),
        actor: users(:one),
        party: party,
        attributes: { preferred_name: "Al" },
        party_lock_version: party.lock_version,
        profile_lock_version: party.person.lock_version - 1
      ).call
    end

    assert_equal :conflict, error.code
  end
end

class LinkMembershipPersonTest < ActiveSupport::TestCase
  test "creates a person that can be linked on membership create" do
    person = LinkMembershipPerson.allocate_person(
      agency: agencies(:one),
      given_name: "Link",
      family_name: "New",
      actor: users(:one)
    )
    user = User.create!(
      email_address: "link-new@example.com",
      first_name: "Link",
      last_name: "New",
      password: "password",
      password_confirmation: "password"
    )
    membership = AgencyMembership.create!(
      user:,
      agency: agencies(:one),
      person_party: person,
      role: "staff",
      status: "invited"
    )

    result = LinkMembershipPerson.new(
      agency: agencies(:one),
      membership: membership,
      person: person,
      source: "test",
      audit_link: true,
      actor: users(:one)
    ).call

    assert result.ok?
    assert_equal person.party_id, membership.reload.person_party_id
    assert_equal person.party_id, person.id
    assert_includes agencies(:one).audit_events.pluck(:action), "team.person_linked"
  end

  test "is idempotent for the same membership and person" do
    membership = agency_memberships(:one)
    person = membership.person_party

    first = LinkMembershipPerson.new(
      agency: agencies(:one),
      membership: membership,
      person: person,
      source: "test",
      actor: users(:one)
    ).call
    second = LinkMembershipPerson.new(
      agency: agencies(:one),
      membership: membership,
      person: person,
      source: "test",
      actor: users(:one)
    ).call

    assert first.ok?
    assert second.ok?
    assert_equal person.party_id, membership.reload.person_party_id
  end

  test "rejects a conflicting existing link" do
    error = assert_raises(MembershipCommand::Error) do
      LinkMembershipPerson.new(
        agency: agencies(:one),
        membership: agency_memberships(:one),
        person: people(:unlinked),
        source: "test",
        actor: users(:one)
      ).call
    end

    assert_equal :conflict, error.code
  end

  test "rejects a person already linked elsewhere" do
    user = User.create!(
      email_address: "link-taken@example.com",
      first_name: "Link",
      last_name: "Taken",
      password: "password",
      password_confirmation: "password"
    )
    membership = AgencyMembership.create!(
      user:,
      agency: agencies(:one),
      person_party: create_person!(agencies(:one), given_name: "Temp", family_name: "Taken"),
      role: "staff",
      status: "invited"
    )

    error = assert_raises(MembershipCommand::Error) do
      LinkMembershipPerson.new(
        agency: agencies(:one),
        membership: membership,
        person: people(:one),
        source: "test",
        actor: users(:one)
      ).call
    end

    assert_equal :conflict, error.code
  end

  test "rejects a cross-agency person" do
    error = assert_raises(MembershipCommand::Error) do
      LinkMembershipPerson.new(
        agency: agencies(:one),
        membership: agency_memberships(:one),
        person: people(:two),
        source: "test",
        actor: users(:one)
      ).call
    end

    assert_equal :not_found, error.code
  end
end
