require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  GENERIC_LOGIN_ALERT = "Try another email address or password."

  setup { @user = users(:one) }

  test "new" do
    get new_session_path
    assert_response :success
  end

  test "create with valid credentials and a usable membership" do
    post session_path, params: { email_address: @user.email_address, password: "password" }

    assert_redirected_to root_path
    assert cookies[:session_id]
  end

  test "create returns to the originally requested page" do
    get root_path
    assert_redirected_to new_session_path

    post session_path, params: { email_address: @user.email_address, password: "password" }

    assert_redirected_to root_url
  end

  test "create with invalid credentials" do
    post session_path, params: { email_address: @user.email_address, password: "wrong" }

    assert_redirected_to new_session_path
    assert_nil cookies[:session_id]
    assert_equal GENERIC_LOGIN_ALERT, flash[:alert]
  end

  test "create with no active membership fails generically" do
    user = User.create!(
      email_address: "no-membership@example.com",
      first_name: "No",
      last_name: "Membership",
      password: "password",
      password_confirmation: "password"
    )

    post session_path, params: { email_address: user.email_address, password: "password" }

    assert_generic_login_failure(user)
  end

  test "create with a suspended membership fails generically" do
    agency_memberships(:one).update!(status: :suspended)

    post session_path, params: { email_address: @user.email_address, password: "password" }

    assert_generic_login_failure
  end

  test "create with a suspended agency fails generically" do
    agencies(:one).update!(status: :suspended)

    post session_path, params: { email_address: @user.email_address, password: "password" }

    assert_generic_login_failure
  end

  test "create with a closed agency fails generically" do
    agencies(:one).update!(status: :closed)

    post session_path, params: { email_address: @user.email_address, password: "password" }

    assert_generic_login_failure
  end

  test "destroy" do
    sign_in_as(@user)

    delete session_path

    assert_redirected_to new_session_path
    assert_empty cookies[:session_id]
  end

  test "an existing session is terminated after membership suspension" do
    sign_in_as(@user)
    agency_memberships(:one).update!(status: :suspended)

    assert_unusable_session_is_terminated
  end

  test "an existing session is terminated after agency suspension" do
    sign_in_as(@user)
    agencies(:one).update!(status: :suspended)

    assert_unusable_session_is_terminated
  end

  test "an existing session is terminated after agency closure" do
    sign_in_as(@user)
    agencies(:one).update!(status: :closed)

    assert_unusable_session_is_terminated
  end

  test "health check remains publicly reachable" do
    get rails_health_check_path

    assert_response :success
  end

  private
    def assert_generic_login_failure(user = @user)
      assert_redirected_to new_session_path
      assert_nil cookies[:session_id]
      assert_equal GENERIC_LOGIN_ALERT, flash[:alert]
      assert_equal 0, user.sessions.count
    end

    def assert_unusable_session_is_terminated
      assert_difference("Session.count", -1) do
        get root_path
      end

      assert_redirected_to new_session_path
      assert_empty cookies[:session_id]
      assert_equal "Please sign in to continue.", flash[:alert]

      get root_path
      assert_redirected_to new_session_path
    end
end
