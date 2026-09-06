require "test_helper"

class PartyRelationshipTest < ActiveSupport::TestCase
  test "allowed kind pairs persist and disallowed pairs fail at the database" do
    now = Time.current
    allowed = {
      household_member: [ parties(:unlinked), parties(:household_one) ],
      family: [ parties(:unlinked), parties(:maria) ],
      organization_affiliation: [ parties(:maria), parties(:organization_one) ],
      organization_contact: [ parties(:one), parties(:organization_one) ],
      parent_organization: [ parties(:harbor_hotel), parties(:harbor_group) ],
      service_provider_for: [ parties(:harbor_hotel), parties(:bedbank) ]
    }

    allowed.each do |kind, (origin, related)|
      relationship = PartyRelationship.create!(
        agency: agencies(:one),
        origin_party: origin,
        origin_party_kind: origin.party_kind,
        related_party: related,
        related_party_kind: related.party_kind,
        relationship_kind: kind.to_s,
        relationship_label: (kind.to_s == "family" ? "parent_of" : kind.to_s == "organization_affiliation" ? "employee" : nil),
        record_status: "valid"
      )
      assert relationship.persisted?, kind.to_s
    end

    assert_raises(ActiveRecord::StatementInvalid) do
      PartyRelationship.transaction(requires_new: true) do
        PartyRelationship.insert_all!([ {
          agency_id: agencies(:one).id,
          origin_party_id: parties(:unlinked).id,
          origin_party_kind: "person",
          related_party_id: parties(:organization_one).id,
          related_party_kind: "organization",
          relationship_kind: "household_member",
          record_status: "valid",
          created_at: now,
          updated_at: now
        } ])
      end
    end
  end

  test "typed composite foreign keys reject a mismatched party kind" do
    now = Time.current

    assert_raises(ActiveRecord::InvalidForeignKey) do
      PartyRelationship.transaction(requires_new: true) do
        PartyRelationship.insert_all!([ {
          agency_id: agencies(:one).id,
          origin_party_id: parties(:household_one).id,
          origin_party_kind: "person",
          related_party_id: parties(:unlinked).id,
          related_party_kind: "person",
          relationship_kind: "family",
          relationship_label: "spouse_of",
          record_status: "valid",
          created_at: now,
          updated_at: now
        } ])
      end
    end
  end

  test "self relationships are rejected" do
    relationship = PartyRelationship.new(
      agency: agencies(:one),
      origin_party: parties(:unlinked),
      origin_party_kind: "person",
      related_party: parties(:unlinked),
      related_party_kind: "person",
      relationship_kind: "family",
      relationship_label: "other_family"
    )

    assert_not relationship.valid?
  end

  test "overlapping household memberships are allowed" do
    first = CreatePartyRelationship.new(
      agency: agencies(:one),
      actor: users(:one),
      origin_party: parties(:unlinked),
      related_party: parties(:household_one),
      relationship_kind: "household_member",
      effective_from: Date.new(2026, 1, 1)
    ).call.relationship
    second = CreatePartyRelationship.new(
      agency: agencies(:one),
      actor: users(:one),
      origin_party: parties(:unlinked),
      related_party: parties(:household_two),
      relationship_kind: "household_member",
      effective_from: Date.new(2026, 1, 1)
    ).call.relationship

    assert first.record_valid?
    assert second.record_valid?
  end

  test "overlapping affiliation and contact for the same pair conflict" do
    CreatePartyRelationship.new(
      agency: agencies(:one),
      actor: users(:one),
      origin_party: parties(:maria),
      related_party: parties(:organization_one),
      relationship_kind: "organization_affiliation",
      relationship_label: "employee"
    ).call

    error = assert_raises(MembershipCommand::Error) do
      CreatePartyRelationship.new(
        agency: agencies(:one),
        actor: users(:one),
        origin_party: parties(:maria),
        related_party: parties(:organization_one),
        relationship_kind: "organization_contact"
      ).call
    end
    assert_equal :conflict, error.code
  end

  test "spouse uniqueness is unordered" do
    CreatePartyRelationship.new(
      agency: agencies(:one),
      actor: users(:one),
      origin_party: parties(:unlinked),
      related_party: parties(:maria),
      relationship_kind: "family",
      relationship_label: "spouse_of"
    ).call

    error = assert_raises(MembershipCommand::Error) do
      CreatePartyRelationship.new(
        agency: agencies(:one),
        actor: users(:one),
        origin_party: parties(:maria),
        related_party: parties(:unlinked),
        relationship_kind: "family",
        relationship_label: "spouse_of"
      ).call
    end
    assert_equal :conflict, error.code
  end

  test "parent cycles are rejected" do
    CreatePartyRelationship.new(
      agency: agencies(:one),
      actor: users(:one),
      origin_party: parties(:harbor_hotel),
      related_party: parties(:harbor_group),
      relationship_kind: "parent_organization"
    ).call

    error = assert_raises(MembershipCommand::Error) do
      CreatePartyRelationship.new(
        agency: agencies(:one),
        actor: users(:one),
        origin_party: parties(:harbor_group),
        related_party: parties(:harbor_hotel),
        relationship_kind: "parent_organization"
      ).call
    end
    assert_equal :invalid, error.code
  end

  test "purpose assignments cannot outlive the relationship" do
    relationship = CreatePartyRelationship.new(
      agency: agencies(:one),
      actor: users(:one),
      origin_party: parties(:maria),
      related_party: parties(:organization_one),
      relationship_kind: "organization_contact",
      effective_from: Date.new(2026, 1, 1),
      effective_until: Date.new(2026, 6, 1)
    ).call.relationship

    error = assert_raises(MembershipCommand::Error) do
      AssignRelationshipPurpose.new(
        agency: agencies(:one),
        actor: users(:one),
        relationship:,
        purpose: "booking",
        priority: 1,
        effective_from: Date.new(2026, 1, 1),
        effective_until: Date.new(2026, 12, 1)
      ).call
    end
    assert_equal :invalid, error.code
  end
end
