require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  test "signed-in user sees the current agency name" do
    sign_in_as(users(:one))

    get root_path

    assert_response :success
    assert_includes response.body, agencies(:one).name
  end

  test "unauthenticated visitor cannot reach the dashboard" do
    get root_path

    assert_redirected_to new_session_path
    assert_not_includes response.body, agencies(:one).name
  end
end
