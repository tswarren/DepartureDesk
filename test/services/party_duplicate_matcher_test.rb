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

  test "narrows and caps candidates without scanning unrelated people" do
    match = PartyDuplicateMatcher.new(
      agency: agencies(:one),
      party_kind: "person",
      attributes: { given_name: "Alex", family_name: "Morgan" },
      party_ids: [ parties(:one).id ]
    ).call
    assert match.none?

    CreateParty.new(
      agency: agencies(:one),
      actor: users(:one),
      party_kind: "person",
      attributes: { given_name: "Alex", family_name: "Morgan" },
      create_anyway: true,
      acknowledged_candidate_ids: [ parties(:unlinked).id ],
      acknowledged_strength: "possible"
    ).call

    capped = PartyDuplicateMatcher.new(
      agency: agencies(:one),
      party_kind: "person",
      attributes: { given_name: "Alex", family_name: "Morgan" },
      limit: 1
    ).call
    assert_equal 1, capped.candidates.size
    assert capped.possible?
  end

  test "keeps a strong person match that sorts after the candidate cap" do
    9.times do
      create_person!(agencies(:one), given_name: "Alex", family_name: "Morgan", date_of_birth: Date.new(1970, 1, 1))
    end
    strong = create_person!(
      agencies(:one),
      given_name: "Alex",
      family_name: "Morgan",
      date_of_birth: Date.new(1990, 5, 1)
    )

    match = PartyDuplicateMatcher.new(
      agency: agencies(:one),
      party_kind: "person",
      attributes: { given_name: "Alex", family_name: "Morgan", date_of_birth: "1990-05-01" }
    ).call
    strong_candidate = match.candidates.find { |candidate| candidate.party_id == strong.party_id }

    assert match.strong?
    assert_equal PartyDuplicateMatcher::CANDIDATE_LIMIT, match.candidates.size
    assert_equal strong.party_id, match.candidates.first.party_id
    assert_equal "strong", strong_candidate.strength
    assert_includes strong_candidate.signals, "date_of_birth"
  end

  test "keeps a strong organization match that sorts after the candidate cap" do
    10.times do
      create_organization!(agencies(:one), legal_name: "Duplicate Line Ltd")
    end
    strong = create_organization!(
      agencies(:one),
      legal_name: "Duplicate Line Ltd",
      website: "https://www.duplicate-line.example"
    )

    match = PartyDuplicateMatcher.new(
      agency: agencies(:one),
      party_kind: "organization",
      attributes: { legal_name: "Duplicate Line Ltd", website: "https://duplicate-line.example" }
    ).call
    strong_candidate = match.candidates.find { |candidate| candidate.party_id == strong.party_id }

    assert match.strong?
    assert_equal PartyDuplicateMatcher::CANDIDATE_LIMIT, match.candidates.size
    assert_equal strong.party_id, match.candidates.first.party_id
    assert_equal "strong", strong_candidate.strength
    assert_includes strong_candidate.signals, "website"
  end
end
