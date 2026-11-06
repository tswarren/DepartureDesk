require "application_system_test_case"

# Demonstration case D12 (first-slice charter). Rules: SUP-22, SUP-23, OPS-03.
class DemonstrationD12Test < ApplicationSystemTestCase
  setup do
    set_clock Time.utc(2026, 10, 15, 14)
    @scenario = AlphaScenario.load!
    @departure = @scenario.alpha.departure
  end

  teardown do
    AlphaScenario.cleanup!(@scenario)
  end

  test "D12: recorded deadlines create owned tasks that go overdue" do
    deadlines = SupplierDeadline.where(supplier_arrangement: @scenario.alpha.arrangements.values).includes(:task)
    assert deadlines.all? { |deadline| deadline.task&.owner == @scenario.actor }, "every actionable deadline has an owned task"
    final_count = deadlines.find_by!(deadline_type: "final_count")
    assert_equal Time.find_zone("America/New_York").local(2027, 10, 22, 23, 59), final_count.task.due_at

    set_clock Time.utc(2026, 11, 3, 14)
    sign_in_from_browser(@scenario.actor, password: M1DirectoryScenario::PASSWORD)
    within("tr", text: "Initial deposit") { assert_text "Overdue" }
    within("tr", text: "Final count") do
      assert_text "Oct 22, 2027, 11:59 PM America/New_York"
      assert_no_text "Overdue"
    end
    assert_selector "tbody tr", text: "Overdue", count: 1

    click_link_and_expect "Alpha Cruises: Initial deposit, $50 per stateroom", heading: "Alpha Cruises: Initial deposit, $50 per stateroom"
    fill_in "Completion note", with: "Deposit wired Nov 2, ref AC-5512"
    click_button_and_expect "Complete task", text: "Task completed."

    visit tasks_path
    wait_for_turbo
    assert_selector "h1.dd-page-title", text: "My tasks"
    assert_no_text "Initial deposit"
    assert_text "Final count"
  end
end
