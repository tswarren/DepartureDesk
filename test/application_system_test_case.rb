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
    wait_until_turbo_session
  end

  def click_link_and_expect(locator, heading:, path: nil, **click_options)
    TURBO_CLICK_ATTEMPTS.times do |attempt|
      begin
        wait_for_turbo
        arrived = has_selector?("h1.dd-page-title", exact_text: heading, wait: 0)
        arrived &&= path.nil? || current_path == path
        unless arrived
          link = find("a", exact_text: locator, **click_options)
          if path
            assert_equal path, URI.parse(link[:href]).path
          end
          scroll_to(link, align: :center)
          link.click
          wait_for_turbo
        end
        assert_selector "h1.dd-page-title", exact_text: heading
        assert_equal path, current_path if path
        wait_for_turbo
        return
      rescue Capybara::ExpectationNotMet, Capybara::ElementNotFound, Minitest::Assertion
        raise if attempt == TURBO_CLICK_ATTEMPTS - 1
      end
    end
  end

  def click_button_and_expect(locator, text:, **click_options)
    TURBO_CLICK_ATTEMPTS.times do |attempt|
      begin
        wait_for_turbo
        unless has_text?(text, wait: 0)
          button = find_button(locator, **click_options)
          scroll_to(button, align: :center)
          button.click
          wait_for_turbo
        end
        assert_text text
        return
      rescue Capybara::ExpectationNotMet, Capybara::ElementNotFound, Minitest::Assertion
        raise if attempt == TURBO_CLICK_ATTEMPTS - 1
      end
    end
  end

  def add_party_role(role_noun, office_label:)
    wait_for_turbo
    unless has_css?("##{role_noun}_profile_create_form", wait: 0)
      click_party_tab "Roles"
      wait_for_turbo
      click_link "Add #{role_noun} role"
      wait_for_turbo
    end
    within("##{role_noun}_profile_create_form") do
      select office_label, from: "#{role_noun.titleize} responsible office"
    end
    click_button_and_expect "Add #{role_noun} role", text: "#{role_noun.titleize} role added."
  end

  def deactivate_party_from_record(reason)
    click_party_tab "Record"
    click_link "Deactivate party"
    fill_in "Party deactivation reason", with: reason
    click_button "Deactivate party"
    wait_for_turbo
  end

  def reactivate_party_from_record(reason)
    click_party_tab "Record"
    unless has_field?("Party reactivation reason", wait: 0)
      click_link "Reactivate party"
      wait_for_turbo
    end
    fill_in "Party reactivation reason", with: reason
    click_button "Reactivate party"
    wait_for_turbo
  end

  def click_button_accepting_confirm(locator)
    wait_for_turbo
    button = find_button(locator)
    scroll_to(button, align: :center)
    accept_confirm { button.click }
    wait_for_turbo
  end

  def fill_in_html_date(locator, iso_date)
    find_field(locator).execute_script("this.value = arguments[0]", iso_date)
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
    click_primary_nav "Directory", heading: "People, households, and organizations"
  end

  def open_clients
    click_primary_nav "Clients", heading: "Clients"
  end

  def open_suppliers
    click_primary_nav "Suppliers", heading: "Suppliers"
  end

  def open_administration
    click_link_and_expect "Administration", heading: "Agency profile"
  end

  def click_party_tab(name)
    TURBO_CLICK_ATTEMPTS.times do |attempt|
      begin
        wait_for_turbo
        href = within("nav[aria-label=Party]") { find("a", exact_text: name)[:href] }
        target_path = URI.parse(href).path
        unless current_path == target_path
          visit href
          wait_for_turbo
        end
        assert_selector "nav[aria-label=Party] a[aria-current=page]", exact_text: name
        assert_equal target_path, current_path
        wait_for_turbo
        return
      rescue Capybara::ExpectationNotMet, Capybara::ElementNotFound, Minitest::Assertion
        raise if attempt == TURBO_CLICK_ATTEMPTS - 1
      end
    end
  end

  def open_directory_party(display_name)
    open_directory
    wait_for_turbo
    href = nil
    within("table.dd-table") do
      href = find("a", exact_text: display_name)[:href]
    end
    # Follow the table href with visit so an in-flight Turbo click cannot
    # cancel navigation and leave the directory index in place.
    visit href
    assert_selector "h1.dd-page-title", exact_text: display_name
    wait_for_turbo
    assert_selector "nav[aria-label=Party]"
  end

  private

  def click_primary_nav(locator, heading:)
    expect_heading_after(heading) do
      within("nav[aria-label='Primary navigation']") { click_link locator, exact: true }
    end
  end

  def wait_until_turbo_session
    return unless page.driver.respond_to?(:evaluate_script)

    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + Capybara.default_max_wait_time
    loop do
      begin
        return if page.evaluate_script("typeof Turbo === 'object' && Turbo !== null")
      rescue Selenium::WebDriver::Error::JavascriptError, Selenium::WebDriver::Error::UnknownError
        # The document can be replaced while a visit is in flight.
      end
      if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
        raise Minitest::Assertion, "Turbo did not become ready"
      end
      sleep 0.05
    end
  end

  def expect_heading_after(heading)
    TURBO_CLICK_ATTEMPTS.times do |attempt|
      begin
        wait_for_turbo
        unless has_selector?("h1.dd-page-title", exact_text: heading, wait: 0)
          yield
          wait_for_turbo
        end
        assert_selector "h1.dd-page-title", exact_text: heading
        wait_for_turbo
        return
      rescue Capybara::ExpectationNotMet, Capybara::ElementNotFound, Minitest::Assertion
        raise if attempt == TURBO_CLICK_ATTEMPTS - 1
      end
    end
  end
end
