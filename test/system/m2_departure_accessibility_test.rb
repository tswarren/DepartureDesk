require "application_system_test_case"

class M2DepartureAccessibilityTest < ApplicationSystemTestCase
  test "empty and filtered-empty index show no departures matched" do
    empty = M1DirectoryScenario.empty
    sign_in_from_browser(empty.actor, password: M1DirectoryScenario::PASSWORD)
    visit departures_path
    wait_for_turbo
    assert_text "No departures matched."

    click_button "Sign out"
    wait_for_turbo

    shell = M2DepartureScenario.celebrity
    sign_in_from_browser(shell.directory.actor, password: M1DirectoryScenario::PASSWORD)
    visit departures_path
    wait_for_turbo
    fill_in "Search", with: "zzznomatch"
    click_button "Apply"
    wait_for_turbo
    assert_text "No departures matched."
  end

  test "form error summary focuses itself and a field link" do
    shell = M2DepartureScenario.celebrity
    sign_in_from_browser(shell.directory.actor, password: M1DirectoryScenario::PASSWORD)
    visit new_departure_path
    wait_for_turbo
    click_button "Save for later"
    wait_for_turbo
    assert_selector "#form-error-summary"
    assert_selector "#form-error-summary:focus"
    assert_equal "form-error-summary", page.evaluate_script("document.activeElement && document.activeElement.id")
    within("#form-error-summary") { find("a").click }
    assert_equal "departure_name", page.evaluate_script("document.activeElement && document.activeElement.id")
  end

  test "representative tab order has identity and visible focus on filter and new form" do
    shell = M2DepartureScenario.celebrity
    sign_in_from_browser(shell.directory.actor, password: M1DirectoryScenario::PASSWORD)

    visit departures_path
    wait_for_turbo
    find_field("Search").send_keys(:tab)
    assert_equal "status", focused_name
    assert_visible_focus
    page.send_keys(:tab)
    assert_equal "responsible_office_id", focused_name
    assert_visible_focus

    visit new_departure_path
    wait_for_turbo
    find_field("Departure name").send_keys(:tab)
    assert_equal "departure[timing_mode]", focused_name
    assert_visible_focus
  end

  test "375px drawer opens closes traps focus and restores the toggle on Departures" do
    shell = M2DepartureScenario.celebrity
    sign_in_from_browser(shell.directory.actor, password: M1DirectoryScenario::PASSWORD)
    resize_window 375, 800
    visit departures_path
    wait_for_turbo

    toggle = find("button.dd-drawer-toggle")
    toggle.send_keys(:return)
    assert_selector ".dd-sidebar.is-open"
    assert_equal "true", toggle["aria-expanded"]
    focused = page.evaluate_script("document.activeElement && document.activeElement.getAttribute('aria-label')")
    assert_equal "Close navigation", focused
    assert page.evaluate_script("document.querySelector('.dd-main').inert")
    assert page.evaluate_script("document.querySelector('.dd-topbar').inert")

    12.times do
      page.send_keys(:tab)
      assert page.evaluate_script("document.querySelector('.dd-sidebar').contains(document.activeElement)")
    end

    page.send_keys(:escape)
    assert_no_selector ".dd-sidebar.is-open"
    assert page.evaluate_script("document.activeElement && document.activeElement.classList.contains('dd-drawer-toggle')")
    assert_equal false, page.evaluate_script("document.querySelector('.dd-main').inert")
  end

  test "departure list profile and forms do not overflow at required widths" do
    shell = M2DepartureScenario.celebrity
    sign_in_from_browser(shell.directory.actor, password: M1DirectoryScenario::PASSWORD)

    [ 375, 768, 1280, 1400 ].each do |width|
      resize_window width, 900
      visit departures_path
      wait_for_turbo
      assert_no_page_overflow
      visit departure_path(shell.departure)
      wait_for_turbo
      assert_no_page_overflow
      visit new_departure_path
      wait_for_turbo
      assert_no_page_overflow
      visit edit_departure_path(shell.departure)
      wait_for_turbo
      assert_no_page_overflow
    end
  end

  private

  def focused_name
    page.evaluate_script("document.activeElement && document.activeElement.getAttribute('name')")
  end

  def assert_visible_focus
    style = page.evaluate_script(<<~JS)
      (() => {
        const el = document.activeElement;
        if (!el) return {};
        const cs = window.getComputedStyle(el);
        return { outlineStyle: cs.outlineStyle, outlineWidth: cs.outlineWidth, boxShadow: cs.boxShadow };
      })()
    JS
    visible = (style["outlineStyle"] != "none" && style["outlineWidth"] != "0px") || (style["boxShadow"].present? && style["boxShadow"] != "none")
    assert visible, "expected a visible focus ring on #{page.evaluate_script('document.activeElement && document.activeElement.outerHTML')}"
  end
end
