require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  test "the same email is an independent account in each agency" do
    post session_path, params: sign_in_params(workspace_code: "harbor", email_address: "alex@example.com")
    assert_redirected_to root_path
    harbor_session = Session.order(:created_at).last
    assert_equal agency_users(:harbor_admin), harbor_session.agency_user

    delete session_path
    post session_path, params: sign_in_params(workspace_code: "cove", email_address: "alex@example.com", password: "cove-password1")
    assert_redirected_to root_path
    cove_session = Session.order(:created_at).last
    assert_equal agency_users(:cove_admin), cove_session.agency_user
    assert_not_equal harbor_session.agency_user.password_digest, cove_session.agency_user.password_digest
  end

  test "a harbor password does not sign in the cove account" do
    post session_path, params: sign_in_params(workspace_code: "cove", email_address: "alex@example.com")

    assert_redirected_to new_session_path
    assert_equal AgencyCommand::GENERIC_FAILURE, flash[:alert]
    assert_nil Session.last
  end

  test "missing workspace, unknown email, bad password, and inactive accounts fail the same way" do
    attempts = [
      { workspace_code: "missing", email_address: "alex@example.com" },
      { workspace_code: "harbor", email_address: "nobody@example.com" },
      { workspace_code: "harbor", email_address: "alex@example.com", password: "not-the-password" },
      { workspace_code: "harbor", email_address: "invite@example.com" },
      { workspace_code: "harbor", email_address: "suspended@example.com" }
    ]

    alerts = attempts.map do |attempt|
      post session_path, params: sign_in_params(**attempt)
      flash[:alert]
    end

    assert_equal [ AgencyCommand::GENERIC_FAILURE ] * attempts.size, alerts
  end

  test "a request agency id does not establish tenancy" do
    post session_path, params: sign_in_params(workspace_code: "harbor", email_address: "alex@example.com", agency_id: agencies(:cove).id)

    assert_redirected_to root_path
    assert_equal agencies(:harbor), Session.order(:created_at).last.agency_user.agency
  end

  test "sign-in rate limit uses ip plus workspace plus email" do
    with_memory_cache do
      10.times do
        post session_path, params: sign_in_params(workspace_code: "harbor", email_address: "alex@example.com")
        assert_redirected_to root_path
      end

      post session_path, params: sign_in_params(workspace_code: "harbor", email_address: "alex@example.com")
      assert_redirected_to new_session_path

      post session_path, params: sign_in_params(workspace_code: "cove", email_address: "alex@example.com", password: "cove-password1")
      assert_redirected_to root_path

      post session_path, params: sign_in_params(workspace_code: "harbor", email_address: "sam@example.com")
      assert_redirected_to root_path
    end
  end

  test "a presented stale session cookie is cleared and an unpresented cookie is not" do
    user = agency_users(:harbor_staff)
    sign_in_as user
    presented = cookies["session_id"]
    other = user.sessions.create!(credential_version: user.credential_version)
    other_cookie = signed_session_cookie(other)

    ChangeAgencyUserAccess.new(agency_user: user, actor: agency_users(:harbor_admin), status: "suspended").call
    assert_equal 0, user.sessions.count
    assert_equal other_cookie, other_cookie

    cookies["session_id"] = presented
    get root_path
    assert_redirected_to new_session_path
    assert_predicate cookies["session_id"].to_s, :blank?

    cookies["session_id"] = other_cookie
    get root_path
    assert_redirected_to new_session_path
    assert_predicate cookies["session_id"].to_s, :blank?
  end

  private

  def sign_in_params(workspace_code:, email_address:, password: ActiveSupport::TestCase::TEST_PASSWORD, agency_id: nil)
    { workspace_code:, email_address:, password:, agency_id: }.compact
  end

  def with_memory_cache
    previous = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    yield
  ensure
    Rails.cache = previous
  end
end
