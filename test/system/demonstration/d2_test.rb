require "application_system_test_case"

# Demonstration case D2 (first-slice charter, as amended by D-92). Rules:
# SMN-03, SMN-05, SMN-11, SMN-13.
class DemonstrationD2Test < ApplicationSystemTestCase
  include ActiveJob::TestHelper

  setup do
    set_clock Time.utc(2026, 10, 15, 14)
    @scenario = AlphaScenario.load!
    @alpha = @scenario.alpha
    @cruise = @alpha.arrangements.fetch(:cruise)
  end

  teardown do
    AlphaScenario.cleanup!(@scenario)
  end

  test "D2: Agreement A's deposits fall due on schedule" do
    assert_empty amounts_due
    sign_in_from_browser(@scenario.actor, password: M1DirectoryScenario::PASSWORD)
    visit departure_money_path(@alpha.departure)
    within("#exposure") { assert_text "$2,745.00" } # the hotel's $1,745 and the excursion's $1,000
    within("#amounts-due") { assert_text "Nothing has fallen due yet." }

    sweep_at Time.utc(2026, 11, 1, 14)
    initial = amounts_due.sole
    assert_equal [ 160_000, Date.new(2026, 11, 1), 32 ], initial.values_at(:amount_minor_units, :due_on, :quantity)
    visit departure_money_path(@alpha.departure)
    within("#amounts-due tr", text: "Initial deposit, $50 per stateroom") do
      assert_text "November 01, 2026"
      assert_text "$1,600.00"
      assert_text "Unpaid"
    end
    assert_equal 32, shells.count { |shell| shell.status == "available" }, "an amount falling due changes no capacity"
    assert_empty @cruise.cost_lines, "a deposit is never a cost (SMN-03)"

    sweep_at Time.utc(2027, 3, 1, 14)
    full = amounts_due.where.not(unit_shell_id: nil)
    assert_equal 32, full.size
    assert full.all? { |amount| amount.amount_minor_units == 45_000 && amount.due_on == Date.new(2027, 3, 1) }
    assert_equal 1_440_000, full.sum(:amount_minor_units)
    assert_equal shells.map(&:id).sort, full.pluck(:unit_shell_id).sort, "one per cabin"

    sweep_at Time.utc(2027, 3, 2, 14)
    assert_equal 33, amounts_due.count, "running the sweep again posts nothing"
    visit departure_money_path(@alpha.departure)
    within("#amounts-due") { assert_selector "tr", text: "Full deposit, $450 per cabin", count: 32 }
  end

  private

  def amounts_due = AmountDue.where(supplier_arrangement: @cruise)

  def shells = UnitShell.where(inventory_group: @cruise.inventory_groups).includes(:capacity_events).to_a

  def sweep_at(time)
    set_clock time
    perform_enqueued_jobs { PostDueSupplierAmountsJob.perform_now }
  end
end
