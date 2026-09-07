require "test_helper"

class PartyDuplicateMatcherTest < ActiveSupport::TestCase
  test "person name-only matches are possible and never strong" do
    match = PartyDuplicateMatcher.new(
      agency: agencies(:one),
      party_kind: "person",
      attributes: { given_name: "Alex", family_name: "Morgan" }
    ).call

    assert match.possible?
    assert_includes match.candidate_ids, parties(:unlinked).id
    assert_not match.strong?
  end

  test "person name and date of birth is a strong match" do
    people(:unlinked).update!(date_of_birth: Date.new(1990, 5, 1))

    match = PartyDuplicateMatcher.new(
      agency: agencies(:one),
      party_kind: "person",
      attributes: { given_name: "Alex", family_name: "Morgan", date_of_birth: "1990-05-01" }
    ).call

    assert match.strong?
    assert_equal [ parties(:unlinked).id ], match.candidate_ids
  end

  test "household and organization names are possible and website host makes organization strong" do
    household = PartyDuplicateMatcher.new(
      agency: agencies(:one),
      party_kind: "household",
      attributes: { name: "Morgan Household" }
    ).call
    assert household.possible?
    assert_not household.strong?

    organizations(:organization_one).update!(website: "https://www.horizontours.example")
    named = PartyDuplicateMatcher.new(
      agency: agencies(:one),
      party_kind: "organization",
      attributes: { legal_name: "Horizon Tours Limited" }
    ).call
    assert named.possible?

    strong = PartyDuplicateMatcher.new(
      agency: agencies(:one),
      party_kind: "organization",
      attributes: { legal_name: "Horizon Tours Limited", website: "https://horizontours.example" }
    ).call
    assert strong.strong?
    assert_includes strong.candidates.first.signals, "website"
  end

  test "summaries include primary contact and omit administrator notes" do
    contact = create_email_contact!(parties(:unlinked), address: "alex.inbox@example.com", actor: users(:one))
    AssignContactPointPurpose.new(
      agency: agencies(:one),
      actor: users(:one),
      party: parties(:unlinked),
      contact_point: contact,
      purpose: "general",
      priority: 1
    ).call

    match = PartyDuplicateMatcher.new(
      agency: agencies(:one),
      party_kind: "person",
      attributes: { given_name: "Alex", family_name: "Morgan" }
    ).call
    summary = match.candidates.first

    assert_equal "alex.inbox@example.com", summary.primary_contact
    assert_not_includes summary.to_h.values.join, "Restricted credit discussion for administrators only."
    assert_not_includes summary.to_h.values.join, "Prefers morning calls"
  end

  test "does not match another agency" do
    match = PartyDuplicateMatcher.new(
      agency: agencies(:two),
      party_kind: "person",
      attributes: { given_name: "Alex", family_name: "Morgan" }
    ).call

    assert match.none?
  end
end
