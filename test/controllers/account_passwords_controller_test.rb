require "test_helper"

class AccountPasswordsControllerTest < ActionDispatch::IntegrationTest
  test "password change destroys every session and clears only the presented cookie" do
    user = agency_users(:harbor_admin)
    sign_in_as user
    other = user.sessions.create!(credential_version: user.credential_version)
    other_cookie = signed_session_cookie(other)

    patch account_password_path, params: {
      current_password: ActiveSupport::TestCase::TEST_PASSWORD,
      password: "replacement123",
      password_confirmation: "replacement123"
    }

    assert_redirected_to new_session_path
    assert_equal 1, AuditEvent.where(action: "agency_user.password_changed", subject_id: user.id).count
    assert_equal 0, AuditEvent.where(action: "agency_user.password_reset", subject_id: user.id).count
    assert_equal 0, user.sessions.count
    assert_predicate cookies["session_id"].to_s, :blank?
    assert_equal 2, user.reload.credential_version

    cookies["session_id"] = other_cookie
    get root_path
    assert_redirected_to new_session_path
    assert_predicate cookies["session_id"].to_s, :blank?
  end
end
