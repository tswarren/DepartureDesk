require "test_helper"

class PartyNoteContentPolicyTest < ActiveSupport::TestCase
  test "rejects a Luhn-valid card number and obvious secrets" do
    assert_match(/payment-card/, PartyNoteContentPolicy.violation_for("Card 4111 1111 1111 1111 on file"))
    assert_match(/private keys/, PartyNoteContentPolicy.violation_for("-----BEGIN RSA PRIVATE KEY-----\nabc"))
    assert_match(/passwords/, PartyNoteContentPolicy.violation_for("password=hunter2 for the portal"))
  end

  test "allows ordinary travel notes" do
    assert_nil PartyNoteContentPolicy.violation_for("Cabin 4111 is next to the stairs. Call after 4pm.")
  end
end

class PartyNoteCommandsTest < ActiveSupport::TestCase
  test "staff can correct a standard note they did not author" do
    note = party_notes(:standard_alex)
    result = CorrectPartyNote.new(
      agency: agencies(:one),
      actor: users(:staff_one),
      party: parties(:unlinked),
      note:,
      body: "Prefers afternoon calls instead.",
      reason: "Preference changed"
    ).call

    assert result.note.record_active?
    assert note.reload.record_superseded?
    assert_equal result.note.id, note.superseded_by_note_id
    assert_not_includes AuditEvent.order(:created_at).last.details.to_s, "Prefers afternoon calls instead."
  end

  test "staff cannot discover an administrator-only note" do
    error = assert_raises(MembershipCommand::Error) do
      RemovePartyNote.new(
        agency: agencies(:one),
        actor: users(:staff_one),
        party: parties(:unlinked),
        note: party_notes(:admin_only_alex),
        reason: "trying"
      ).call
    end
    assert_equal :not_found, error.code
  end

  test "rejected card details are not audited" do
    assert_no_difference("AuditEvent.count") do
      error = assert_raises(MembershipCommand::Error) do
        CreatePartyNote.new(
          agency: agencies(:one),
          actor: users(:one),
          party: parties(:unlinked),
          body: "Use 4111111111111111",
          visibility: "standard"
        ).call
      end
      assert_equal :invalid, error.code
      assert_no_match(/4111/, error.message)
    end
  end
end
