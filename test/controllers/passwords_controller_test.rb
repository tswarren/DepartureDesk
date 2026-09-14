require "test_helper"

class PasswordsControllerTest < ActionDispatch::IntegrationTest
  test "only an active user in the named workspace receives a reset token" do
    assert_no_difference -> { AgencyUser.where.not(password_reset_token_digest: nil).count } do
      post passwords_path, params: { workspace_code: "harbor", email_address: "nobody@example.com" }
      post passwords_path, params: { workspace_code: "harbor", email_address: "invite@example.com" }
      post passwords_path, params: { workspace_code: "harbor", email_address: "suspended@example.com" }
      post passwords_path, params: { workspace_code: "missing", email_address: "alex@example.com" }
    end

    user = agency_users(:harbor_admin)
    user.update!(password_reset_token_digest: nil, password_reset_sent_at: nil, password_reset_expires_at: nil)
    post passwords_path, params: { workspace_code: "harbor", email_address: "alex@example.com" }

    assert user.reload.password_reset_token_digest.present?
    assert_equal RequestPasswordReset::GENERIC_RESPONSE, flash[:notice]
    assert_nil agency_users(:cove_admin).reload.password_reset_token_digest
  end

  test "password-reset rate limit uses ip plus workspace plus email" do
    with_memory_cache do
      10.times { post passwords_path, params: { workspace_code: "harbor", email_address: "alex@example.com" } }
      digest = agency_users(:harbor_admin).reload.password_reset_token_digest

      post passwords_path, params: { workspace_code: "harbor", email_address: "alex@example.com" }
      assert_equal digest, agency_users(:harbor_admin).reload.password_reset_token_digest

      post passwords_path, params: { workspace_code: "harbor", email_address: "sam@example.com" }
      assert agency_users(:harbor_staff).reload.password_reset_token_digest.present?
    end
  end

  test "a successful reset bumps the credential version and destroys sessions" do
    user = agency_users(:harbor_admin)
    sign_in_as user
    other = user.sessions.create!(credential_version: user.credential_version)
    other_cookie = signed_session_cookie(other)
    raw = user.issue_password_reset_token
    user.save!

    patch password_path(raw), params: { password: "replacement123", password_confirmation: "replacement123" }

    assert_redirected_to new_session_path
    assert_equal 0, user.sessions.count
    assert_nil user.reload.password_reset_token_digest
    assert_equal 2, user.credential_version
    assert user.authenticate("replacement123")

    cookies["session_id"] = other_cookie
    get root_path
    assert_redirected_to new_session_path
    assert_predicate cookies["session_id"].to_s, :blank?
  end

  private

  def with_memory_cache
    previous = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    yield
  ensure
    Rails.cache = previous
  end
end
