require "test_helper"

# "Ready to confirm?" on a draft arrangement and "Ready to sell?" on a draft
# Departure: required items follow the commands' own checks (SUP-11, SUP-12, DEP-05).
class SetupChecklistsTest < ActionDispatch::IntegrationTest
  setup do
    set_clock Time.utc(2026, 10, 15, 14)
    @agency = agencies(:harbor)
    @admin = agency_users(:harbor_admin)
    @alpha = AlphaFixture.load!(agency: @agency, actor: @admin, confirm_cruise: false)
    @departure = @alpha.departure
    @cruise = @alpha.arrangements.fetch(:cruise)
  end

  test "a draft arrangement's checklist shows each requirement, and its required items agree with confirmation" do
    sign_in_as @admin
    get departure_arrangement_path(@departure, @cruise)
    assert_select "#ready-to-confirm h2", text: "Ready to confirm?"
    assert_select "#ready-to-confirm li", text: /Done\s+Payee account/
    assert_select "#ready-to-confirm li", text: /Inventory · 4 groups, 32 units or places\./
    assert_select "#ready-to-confirm li", text: /Supplier rates · Every fare entered\./
    assert_select "#ready-to-confirm h3", text: "Usually set up first, not required to confirm"
    assert_empty @cruise.confirmation_blockers
    assert_select "#ready-to-confirm .dd-cell-subtext", text: "3 of 3 required done"

    @cruise.update_columns(group_reference: nil)
    get departure_arrangement_path(@departure, @cruise)
    assert_select "#ready-to-confirm li", text: /To do\s+The supplier's group or confirmation reference\s+· Fix it/
    assert_select "#ready-to-confirm .dd-cell-subtext", text: "2 of 3 required done"
    assert_not_empty @cruise.reload.confirmation_blockers
  end

  test "a confirmed arrangement has no checklist; staff who can't see cost don't see rates or payments" do
    sign_in_as @admin
    get departure_arrangement_path(@departure, @alpha.arrangements.fetch(:hotel))
    assert_select "#ready-to-confirm", count: 0

    sign_in_as agency_users(:harbor_baseline_staff)
    get departure_arrangement_path(@departure, @cruise)
    assert_select "#ready-to-confirm li", text: /Supplier rates/, count: 0
  end

  test "a draft Departure lists what Ready to sell needs, then what bookings need" do
    departure = CreateDeparture.new(agency: @agency, actor: @admin, attributes: { name: "Spring sampler" }).call.record
    sign_in_as @admin
    get departure_path(departure)
    assert_select "#ready-to-sell h2", text: "Ready to sell?"
    assert_select "#ready-to-sell li", text: /To do\s+Dates · Enter a start date and an end date\./
    assert_select "#ready-to-sell li", text: /Not yet\s+A package clients can book · Add a package\./
    assert_equal departure.ready_to_sell_blockers.any?, css_select("#ready-to-sell li").any? { |li| li.text.include?("To do") }
  end
end
