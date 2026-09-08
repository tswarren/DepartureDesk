require "application_system_test_case"

class NavigationDrawerTest < ApplicationSystemTestCase
  test "mobile drawer traps tab inside the drawer and restores focus to menu" do
    sign_in_from_browser users(:one)
    page.current_window.resize_to(375, 812)
    wait_for_turbo

    menu = find("button[aria-label='Open navigation']", visible: true)
    menu.click
    assert_selector ".dd-sidebar.is-open"
    assert_equal "Close navigation", focused_aria_label
    assert page.evaluate_script("document.querySelector('.dd-topbar').inert")
    assert page.evaluate_script("document.querySelector('.dd-main').inert")

    12.times do
      page.send_keys(:tab)
      assert focused_inside_drawer?, "Tab moved focus outside the open drawer"
    end

    page.execute_script("document.querySelector('[data-navigation-drawer-target=close]').focus()")
    page.send_keys([ :shift, :tab ])
    assert focused_inside_drawer?, "Shift+Tab moved focus outside the open drawer"

    page.send_keys(:escape)
    assert_no_selector ".dd-sidebar.is-open"
    assert_not page.evaluate_script("document.querySelector('.dd-topbar').inert")
    assert_not page.evaluate_script("document.querySelector('.dd-main').inert")
    assert_equal "Open navigation", focused_aria_label
  ensure
    restore_default_window_size
  end

  private

  def focused_aria_label
    page.evaluate_script("document.activeElement && document.activeElement.getAttribute('aria-label')")
  end

  def focused_inside_drawer?
    page.evaluate_script("!!(document.querySelector('#app-navigation') && document.querySelector('#app-navigation').contains(document.activeElement))")
  end
end
