require "test_helper"

class PartyTest < ActiveSupport::TestCase
  test "accepts the three supported kinds" do
    Party::KINDS.each do |kind|
      party = agencies(:one).parties.new(party_kind: kind, status: "active", display_name: "Name", sort_name: "Name")
      assert party.valid?, party.errors.full_messages.to_sentence
    end
  end

  test "rejects an unknown kind in the model" do
    party = agencies(:one).parties.new(status: "active", display_name: "Name", sort_name: "Name")
    party.party_kind = "vendor"

    assert_not party.valid?
    assert party.errors[:party_kind].any?
  end

  test "kind cannot change in the model" do
    party = parties(:one)

    assert_raises(ActiveRecord::ReadonlyAttributeError) do
      party.party_kind = "household"
    end
    assert_equal "person", party.reload.party_kind
  end

  test "kind cannot change in the database" do
    party = parties(:one)

    assert_raises(ActiveRecord::StatementInvalid) do
      Party.transaction(requires_new: true) do
        Party.connection.execute(
          "UPDATE parties SET party_kind = 'household' WHERE id = '#{party.id}'"
        )
      end
    end
  end

  test "requires an agency" do
    party = Party.new(party_kind: "person", status: "active", display_name: "Name", sort_name: "Name")

    assert_not party.valid?
    assert party.errors[:agency].any?
  end

  test "person directory display omits prefix and suffix and prefers preferred name" do
    names = PartyName.person(
      given_name: "Alexandra",
      middle_name: "Jane",
      family_name: "Morgan",
      preferred_name: "Alex",
      prefix: "Dr",
      suffix: "PhD"
    )

    assert_equal "Alex Morgan", names.display_name
    assert_equal "Morgan, Alexandra Jane", names.sort_name
  end

  test "person display uses given middle family without a preferred name" do
    names = PartyName.person(given_name: "Alex", middle_name: "Jane", family_name: "Morgan")

    assert_equal "Alex Jane Morgan", names.display_name
    assert_equal "Morgan, Alex Jane", names.sort_name
  end

  test "household name drives display and sort values" do
    names = PartyName.household(name: "Morgan Household", correspondence_name: "The Morgans")

    assert_equal "Morgan Household", names.display_name
    assert_equal "Morgan Household", names.sort_name
  end

  test "organization display falls back from trading to legal name" do
    with_trading = PartyName.organization(legal_name: "Horizon Tours Limited", trading_name: "Horizon Tours")
    legal_only = PartyName.organization(legal_name: "Horizon Tours Limited")

    assert_equal "Horizon Tours", with_trading.display_name
    assert_equal "Horizon Tours Limited", legal_only.display_name
  end

  test "lifecycle constraint rejects inconsistent metadata in the model" do
    party = parties(:one)
    party.deactivated_at = Time.current

    assert_not party.valid?
    assert party.errors[:deactivated_at].any?
  end

  test "lifecycle constraint rejects inconsistent metadata in the database" do
    party = parties(:one)

    assert_raises(ActiveRecord::StatementInvalid) do
      Party.transaction(requires_new: true) do
        Party.connection.execute(
          "UPDATE parties SET deactivated_at = CURRENT_TIMESTAMP WHERE id = '#{party.id}'"
        )
      end
    end
  end

  test "cross-agency deactivation actor is rejected in the model" do
    party = parties(:one)
    party.status = "deactivated"
    party.deactivated_at = Time.current
    party.deactivated_by_membership = agency_memberships(:two)
    party.deactivation_reason = "closed"

    assert_not party.valid?
    assert party.errors[:deactivated_by_membership].any?
  end

  test "person profile primary key equals the party id" do
    person = people(:one)

    assert_equal person.party_id, person.id
    assert_equal parties(:one).id, person.party_id
  end

  test "household and organization profiles use the party id as primary key" do
    assert_equal parties(:household_one).id, households(:household_one).party_id
    assert_equal parties(:organization_one).id, organizations(:organization_one).party_id
  end

  test "profile agency must match the party agency" do
    person = Person.new(
      party: parties(:one),
      agency: agencies(:two),
      given_name: "Casey",
      family_name: "Nguyen"
    )

    assert_not person.valid?
    assert person.errors[:agency].any?
  end

  test "blank-only required person names are rejected" do
    person = people(:unlinked)
    person.given_name = "   "

    assert_not person.valid?
    assert person.errors[:given_name].any?
  end

  test "membership person_party_id is not null after backfill" do
    column = AgencyMembership.columns_hash.fetch("person_party_id")

    assert_not column.null
    AgencyMembership.find_each do |membership|
      assert membership.person_party_id.present?
      assert_equal membership.agency_id, membership.person_party.agency_id
    end
  end

  test "household and organization ids cannot be stored as person_party_id" do
    membership = AgencyMembership.new(
      user: User.create!(
        email_address: "fk-household@example.com",
        first_name: "Fk",
        last_name: "Household",
        password: "password",
        password_confirmation: "password"
      ),
      agency: agencies(:one),
      role: "staff",
      status: "invited"
    )
    membership.person_party_id = parties(:household_one).id

    assert_raises(ActiveRecord::InvalidForeignKey) do
      AgencyMembership.transaction(requires_new: true) do
        membership.save!(validate: false)
      end
    end
  end

  test "cross-agency person links fail at the database boundary" do
    membership = AgencyMembership.new(
      user: User.create!(
        email_address: "fk-cross@example.com",
        first_name: "Fk",
        last_name: "Cross",
        password: "password",
        password_confirmation: "password"
      ),
      agency: agencies(:one),
      role: "staff",
      status: "invited"
    )
    membership.person_party_id = people(:two).party_id

    assert_raises(ActiveRecord::InvalidForeignKey) do
      AgencyMembership.transaction(requires_new: true) do
        membership.save!(validate: false)
      end
    end
  end

  test "one person cannot link to two memberships in an agency" do
    membership = AgencyMembership.new(
      user: User.create!(
        email_address: "duplicate-person@example.com",
        first_name: "Dup",
        last_name: "Person",
        password: "password",
        password_confirmation: "password"
      ),
      agency: agencies(:one),
      person_party: people(:one),
      role: "staff",
      status: "invited"
    )

    assert_not membership.valid?
    assert membership.errors[:person_party_id].any?

    assert_raises(ActiveRecord::RecordNotUnique) do
      AgencyMembership.transaction(requires_new: true) do
        membership.save!(validate: false)
      end
    end
  end

  test "invited suspended and revoked memberships all have a person" do
    invited = InviteTeamMember.new(
      agency: agencies(:one),
      actor: users(:one),
      email: "invited-person@example.com",
      role: "staff",
      first_name: "Invited",
      last_name: "Person",
      **invite_offices
    ).call.membership
    assert invited.person_party.present?

    RevokeInvitation.new(agency: agencies(:one), actor: users(:one), membership: invited).call
    assert invited.reload.revoked?
    assert invited.person_party.present?

    extra = InviteTeamMember.new(
      agency: agencies(:one),
      actor: users(:one),
      email: "suspended-person@example.com",
      role: "staff",
      first_name: "Suspended",
      last_name: "Person",
      **invite_offices
    ).call.membership
    AcceptInvitation.new(
      token: extra.invitation_token,
      password: "Newpass123!",
      password_confirmation: "Newpass123!"
    ).call
    SuspendMembership.new(agency: agencies(:one), actor: users(:one), membership: extra.reload).call
    assert extra.reload.suspended?
    assert extra.person_party.present?
  end

  test "people households and organizations cannot reference a mismatched party kind" do
    now = Time.current

    assert_raises(ActiveRecord::InvalidForeignKey) do
      Person.transaction(requires_new: true) do
        Person.insert_all!([ {
          party_id: parties(:household_one).id,
          agency_id: agencies(:one).id,
          party_kind: "person",
          given_name: "Wrong",
          family_name: "Kind",
          created_at: now,
          updated_at: now
        } ])
      end
    end

    assert_raises(ActiveRecord::InvalidForeignKey) do
      Household.transaction(requires_new: true) do
        Household.insert_all!([ {
          party_id: parties(:one).id,
          agency_id: agencies(:one).id,
          party_kind: "household",
          name: "Wrong Kind",
          created_at: now,
          updated_at: now
        } ])
      end
    end

    assert_raises(ActiveRecord::InvalidForeignKey) do
      Organization.transaction(requires_new: true) do
        Organization.insert_all!([ {
          party_id: parties(:one).id,
          agency_id: agencies(:one).id,
          party_kind: "organization",
          legal_name: "Wrong Kind",
          created_at: now,
          updated_at: now
        } ])
      end
    end
  end

  test "kind profile party_kind checks reject the other kinds" do
    now = Time.current

    assert_raises(ActiveRecord::StatementInvalid) do
      Person.transaction(requires_new: true) do
        Person.insert_all!([ {
          party_id: parties(:household_one).id,
          agency_id: agencies(:one).id,
          party_kind: "household",
          given_name: "Wrong",
          family_name: "Kind",
          created_at: now,
          updated_at: now
        } ])
      end
    end

    assert_raises(ActiveRecord::StatementInvalid) do
      Household.transaction(requires_new: true) do
        Household.insert_all!([ {
          party_id: parties(:one).id,
          agency_id: agencies(:one).id,
          party_kind: "person",
          name: "Wrong Kind",
          created_at: now,
          updated_at: now
        } ])
      end
    end

    assert_raises(ActiveRecord::StatementInvalid) do
      Organization.transaction(requires_new: true) do
        Organization.insert_all!([ {
          party_id: parties(:one).id,
          agency_id: agencies(:one).id,
          party_kind: "person",
          legal_name: "Wrong Kind",
          created_at: now,
          updated_at: now
        } ])
      end
    end
  end
end
