require "test_helper"
require_relative "test_helpers/system_test_browser"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  if SystemTestBrowser.available?
    driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ]
  else
    driven_by :rack_test

    setup do
      skip "System tests require Chrome and run in GitHub CI. The local Docker image does not include a browser."
    end
  end

  # Capybara's assert_current_path can pass on a Turbo visit's URL before the
  # document is replaced. Wait on unique content after in-app Directory clicks.
  # A click issued while html[aria-busy] is set can cancel the in-flight visit
  # and leave the previous page in place.
  def wait_for_turbo
    assert_no_selector "html[aria-busy=true]"
  end

  def click_link_and_expect(locator, heading:, **click_options)
    click_link locator, **click_options
    assert_selector "h1.dd-page-title", text: heading
    wait_for_turbo
  end

  def sign_in_from_browser(user)
    visit new_session_path
    fill_in "Email address", with: user.email_address
    fill_in "Password", with: "password"
    click_button "Sign in"
    assert_selector "h1.dd-page-title", text: "Dashboard"
    wait_for_turbo
  end

  def open_directory
    click_link_and_expect "Directory",
      heading: "People, households, and organizations",
      exact: true
  end

  def open_administration
    click_link_and_expect "Administration", heading: "Agency profile"
  end

  def open_directory_party(display_name)
    open_directory
    within("table.dd-table") { click_link display_name, exact: true }
    assert_selector "nav[aria-label=Party]"
    assert_selector "h1.dd-page-title", text: display_name
    wait_for_turbo
  end
end
