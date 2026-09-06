require "test_helper"
require_relative "test_helpers/system_test_browser"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  TURBO_CLICK_ATTEMPTS = 3

  if SystemTestBrowser.available?
    driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ]
    Capybara.default_max_wait_time = 5
  else
    driven_by :rack_test

    setup do
      skip "System tests require Chrome and run in GitHub CI. The local Docker image does not include a browser."
    end
  end

  # Capybara's assert_current_path can pass on a Turbo visit's URL before the
  # document is replaced. A click issued while a visit is in flight can be
  # cancelled and leave the previous page in place. Wait on unique content,
  # then retry the click if the destination heading never appears.
  def wait_for_turbo
    assert_no_selector "html[aria-busy=true]"
  end

  def click_link_and_expect(locator, heading:, **click_options)
    expect_heading_after(heading) { click_link locator, **click_options }
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
    expect_heading_after(display_name) do
      within("table.dd-table") { click_link display_name, exact: true }
    end
    assert_selector "nav[aria-label=Party]"
  end

  private

  def expect_heading_after(heading)
    TURBO_CLICK_ATTEMPTS.times do |attempt|
      begin
        yield unless has_selector?("h1.dd-page-title", exact_text: heading, wait: 0)
        assert_selector "h1.dd-page-title", exact_text: heading
        wait_for_turbo
        return
      rescue Capybara::ExpectationNotMet, Capybara::ElementNotFound, Minitest::Assertion
        raise if attempt == TURBO_CLICK_ATTEMPTS - 1
      end
    end
  end
end
