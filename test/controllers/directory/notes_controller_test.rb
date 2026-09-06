require "test_helper"

module Directory
  class NotesControllerTest < ActionDispatch::IntegrationTest
    test "administrator sees both visibilities and staff cannot infer restricted notes" do
      sign_in_as(users(:one))
      get directory_party_notes_path(parties(:unlinked))
      assert_response :success
      assert_includes response.body, party_notes(:standard_alex).body
      assert_includes response.body, party_notes(:admin_only_alex).body
      assert_select "nav[aria-label=Party] a[aria-current=page]", text: "Notes"

      assert_no_difference("AuditEvent.count") do
        get directory_party_notes_path(parties(:unlinked))
      end

      sign_out
      sign_in_as(users(:staff_one))
      get directory_party_notes_path(parties(:unlinked))
      assert_response :success
      assert_includes response.body, party_notes(:standard_alex).body
      assert_not_includes response.body, party_notes(:admin_only_alex).body
      assert_not_includes response.body, "Administrator only"
      assert_select "h3.dd-empty-title", text: "No notes", count: 0

      post remove_directory_party_party_note_path(parties(:unlinked), party_notes(:admin_only_alex)), params: { reason: "nope" }
      assert_response :not_found
    end

    test "corrected notes remain visible in history" do
      sign_in_as(users(:one))
      note = party_notes(:standard_alex)
      original_body = note.body
      post correct_directory_party_party_note_path(parties(:unlinked), note), params: {
        party_note: { body: "Prefers afternoon calls.", reason: "Preference changed" }
      }
      assert_redirected_to directory_party_notes_path(parties(:unlinked))
      follow_redirect!
      assert_includes response.body, "Prefers afternoon calls."
      assert_includes response.body, original_body
      assert_includes response.body, "Superseded"
    end

    test "staff cannot infer superseded administrator-only notes" do
      sign_in_as(users(:one))
      original_body = party_notes(:admin_only_alex).body
      post correct_directory_party_party_note_path(parties(:unlinked), party_notes(:admin_only_alex)), params: {
        party_note: { body: "Replacement restricted discussion.", reason: "Updated" }
      }
      assert_redirected_to directory_party_notes_path(parties(:unlinked))

      sign_out
      sign_in_as(users(:staff_one))
      get directory_party_notes_path(parties(:unlinked))
      assert_response :success
      assert_not_includes response.body, original_body
      assert_not_includes response.body, "Replacement restricted discussion."
      assert_not_includes response.body, "Administrator only"
    end

    test "cross-agency notes return not found" do
      sign_in_as(users(:one))
      get directory_party_notes_path(parties(:two))
      assert_response :not_found
    end
  end
end
