require "application_system_test_case"

class SignInTest < ApplicationSystemTestCase
  test "signed-in user sees the current agency name" do
    visit new_session_path

    fill_in "Email address", with: users(:one).email_address
    fill_in "Password", with: "password"
    click_button "Sign in"

    assert_text agencies(:one).name
    assert_text "Dashboard"
  end
end
