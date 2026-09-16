require "application_system_test_case"

class M1DirectoryAccessibilityTest < ApplicationSystemTestCase
  test "375px drawer opens closes traps focus and restores the toggle" do
    scenario = M1DirectoryScenario.celebrity
    sign_in_from_browser(scenario.actor, password: M1DirectoryScenario::PASSWORD)
    resize_window 375, 800
    visit root_path
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

  test "representative directory surfaces do not overflow at required widths" do
    scenario = M1DirectoryScenario.celebrity
    sign_in_from_browser(scenario.actor, password: M1DirectoryScenario::PASSWORD)

    [ 375, 768, 1280, 1400 ].each do |width|
      resize_window width, 900
      visit clients_path
      wait_for_turbo
      assert_no_page_overflow
      assert_selector "label", text: "Search"
      assert_selector "a, button", text: /New Client|Apply/
      visit client_person_path(scenario.martha)
      wait_for_turbo
      assert_no_page_overflow
      visit suppliers_path
      wait_for_turbo
      assert_no_page_overflow
      visit supplier_path(scenario.celebrity)
      wait_for_turbo
      assert_no_page_overflow
    end
  end

  test "native controls keep accessible names on client and supplier forms" do
    scenario = M1DirectoryScenario.celebrity
    sign_in_from_browser(scenario.actor, password: M1DirectoryScenario::PASSWORD)

    visit new_client_path
    assert_selector "label", text: "First name"
    assert_selector "label", text: "Last name"
    assert find_field("First name")[:id].present?
    visit new_supplier_path
    assert_selector "label", text: "Display name"
    assert_button "Save supplier"
  end

  test "client and supplier filter forms have a logical tab order with visible focus" do
    scenario = M1DirectoryScenario.celebrity
    sign_in_from_browser(scenario.actor, password: M1DirectoryScenario::PASSWORD)

    visit clients_path
    wait_for_turbo
    find_field("Search").send_keys(:tab)
    assert_equal "kind", focused_name
    assert_visible_focus
    page.send_keys(:tab)
    assert_equal "status", focused_name
    assert_visible_focus
    page.send_keys(:tab)
    assert_equal "Apply", focused_button_or_link
    assert_visible_focus

    visit new_client_path
    wait_for_turbo
    find_field("First name").send_keys(:tab)
    assert_equal "client_person[middle_name]", focused_name
    assert_visible_focus
    page.send_keys(:tab)
    assert_equal "client_person[last_name]", focused_name
    assert_visible_focus

    visit suppliers_path
    wait_for_turbo
    find_field("Search").send_keys(:tab)
    assert_equal "kind", focused_name
    assert_visible_focus
    page.send_keys(:tab)
    assert_equal "category", focused_name
    assert_visible_focus
    page.send_keys(:tab)
    assert_equal "status", focused_name
    assert_visible_focus
    page.send_keys(:tab)
    assert_equal "Apply", focused_button_or_link
    assert_visible_focus
  end

  private

  def focused_name
    page.evaluate_script("document.activeElement && document.activeElement.getAttribute('name')")
  end

  def focused_button_or_link
    page.evaluate_script("document.activeElement && (document.activeElement.value || document.activeElement.textContent.trim())")
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
