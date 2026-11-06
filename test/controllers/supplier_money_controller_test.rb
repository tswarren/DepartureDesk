require "test_helper"

# S-16 and the Departure's Supplier money tab: SMN-02, SMN-04, SMN-05, SMN-11, SMN-12, ACC-31.
class SupplierMoneyControllerTest < ActionDispatch::IntegrationTest
  setup do
    set_clock Time.utc(2026, 10, 15, 14)
    @agency = agencies(:harbor)
    @admin = agency_users(:harbor_admin)
    @alpha = AlphaFixture.load!(agency: @agency, actor: @admin)
    @departure = @alpha.departure
    @excursion = @alpha.arrangements.fetch(:excursion)
    @hotel = @alpha.arrangements.fetch(:hotel)
  end

  test "an admin adds a commitment naming shells and a schedule line, and records an event that posts it" do
    sign_in_as @admin
    group = @hotel.inventory_groups.find_by!(label: "Nov 5 Garden Queen")
    get new_departure_arrangement_cost_line_path(@departure, @hotel)
    assert_select "label", text: group.unit_shells.first.label

    post departure_arrangement_cost_lines_path(@departure, @hotel), params: { cost_line: {
      description: "Late checkout", scope: "unit_shells", unit_shell_ids: group.unit_shells.first(2).map(&:id), basis: "per_unit", rate: "40", stage: "committed"
    } }
    assert_redirected_to departure_arrangement_path(@departure, @hotel, anchor: "supplier-cost")
    cost = @hotel.cost_lines.find_by!(description: "Late checkout")
    assert_equal 8_000, cost.amount_minor_units

    post departure_arrangement_schedule_lines_path(@departure, @hotel), params: { schedule_line: {
      description: "Late checkout on invoice", cost_line_id: cost.id, amount_kind: "percentage_of_cost_line", percentage: "100",
      due_rule: "event", trigger_type: "supplier_invoice_received"
    } }
    line = @hotel.schedule_lines.find_by!(description: "Late checkout on invoice")

    post departure_arrangement_trigger_events_path(@departure, @hotel), params: { trigger_event: { event_type: "supplier_invoice_received", occurred_on: "2026-10-14", reference: "INV-77" } }
    assert_equal [ 8_000, Date.new(2026, 10, 14) ], line.amounts_due.sole.values_at(:amount_minor_units, :due_on)

    get departure_arrangement_path(@departure, @hotel)
    assert_select "#supplier-cost th[scope=row]", text: "Late checkout"
    assert_select "#supplier-cost td", text: /\$40\.00 × 2 per unit\z/
    assert_select "#supplier-cost li", text: /Supplier invoice received, October 14, 2026, ref INV-77/
    assert_select "#supplier-cost td", text: /Schedule line: Late checkout on invoice\z/
  end

  test "an invalid amount re-renders with the error on its field" do
    sign_in_as @admin
    post departure_arrangement_schedule_lines_path(@departure, @hotel), params: { schedule_line: {
      description: "Bad", amount_kind: "per_shell", rate: "1.234", due_rule: "fixed_date", due_on: "2027-01-01"
    } }
    assert_response :unprocessable_entity
    assert_select "#form-error-summary a[href='#schedule_line_rate']", text: /Amount per unit must be an amount in USD/
  end

  test "completing the excursion's final-count task over HTTP records the count and posts the resource payment (SMN-12)" do
    task = @excursion.deadlines.find_by!(deadline_type: "final_count").task
    sign_in_as @admin
    get task_path(task)
    assert_select "legend", text: "Records: Final count or manifest submitted"
    post task_completion_path(task), params: { lock_version: task.lock_version, completion_note: "Count of 9 sent", event_occurred_on: "2026-10-15", event_count: "9" }
    assert_redirected_to task_path(task)
    assert_equal [ 100_000 ], @excursion.amounts_due.pluck(:amount_minor_units)
  end

  test "Departure management sees supplier money but can't edit it; baseline staff see neither (ACC-31)" do
    sign_in_as agency_users(:harbor_staff)
    get departure_arrangement_path(@departure, @hotel)
    assert_select "#supplier-cost"
    assert_select "#supplier-cost a", text: "Add cost line", count: 0
    get departure_supplier_money_path(@departure)
    assert_select "#exposure", text: /\$2,745\.00/
    get new_departure_arrangement_cost_line_path(@departure, @hotel)
    assert_redirected_to root_path

    sign_in_as agency_users(:harbor_baseline_staff)
    get departure_arrangement_path(@departure, @hotel)
    assert_select "#supplier-cost", count: 0
    assert_select "nav[aria-label='Departure sections'] a", text: "Supplier money", count: 0
    get departure_supplier_money_path(@departure)
    assert_redirected_to root_path
  end

  test "Financial records may record a direct amount due" do
    staff = agency_users(:harbor_baseline_staff)
    UserPermission.create!(agency: @agency, agency_user: staff, permission: "financial_records")
    sign_in_as staff
    post departure_arrangement_amounts_due_path(@departure, @hotel), params: { amount_due: { description: "Resort fee", amount: "35", due_on: "2027-11-06" } }
    assert_redirected_to departure_arrangement_path(@departure, @hotel, anchor: "supplier-cost")
    assert_equal [ 3_500 ], @hotel.amounts_due.pluck(:amount_minor_units)
  end

  test "other agencies get not found" do
    sign_in_as agency_users(:cove_admin)
    get departure_supplier_money_path(@departure)
    assert_response :not_found
    get new_departure_arrangement_cost_line_path(@departure, @hotel)
    assert_response :not_found
  end
end
