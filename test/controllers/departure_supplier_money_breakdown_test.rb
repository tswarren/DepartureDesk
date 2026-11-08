require "test_helper"

# The Supplier money tab's breakdown of committed cost, by arrangement or by booking (SMN-02, SMN-05, SMN-32, ACC-31).
class DepartureSupplierMoneyBreakdownTest < ActionDispatch::IntegrationTest
  setup do
    set_clock Time.utc(2027, 1, 10, 15)
    @agency = agencies(:harbor)
    @alpha = AlphaFixture.load!(agency: @agency, actor: agency_users(:harbor_admin), bookings: :confirmed)
    set_clock Time.utc(2027, 2, 3, 15)
    @departure = @alpha.departure
  end

  test "by arrangement lists each arrangement's committed cost and its cost lines, with the booking each is for" do
    sign_in_as agency_users(:harbor_admin)
    get departure_supplier_money_path(@departure)
    assert_select "nav[aria-label='Break committed cost down'] a[aria-current=page]", text: "By arrangement"
    cruise = @alpha.arrangements.fetch(:cruise)
    section = css_select("#breakdown section").find { |node| node.text.include?(cruise.arrangement_reference) }
    booking = @alpha.bookings.fetch("BK-104")
    assert_includes section.text, booking.booking_reference
    assert_includes section.text, Money.new(cruise.cost_lines.select(&:stage_committed?).sum(&:amount_minor_units), "USD").format
    assert_select "#breakdown h2", text: "By arrangement"
  end

  test "by booking totals each booking's supplier cost, commission and net" do
    sign_in_as agency_users(:harbor_admin)
    get departure_supplier_money_path(@departure, view: "booking")
    assert_select "nav[aria-label='Break committed cost down'] a[aria-current=page]", text: "By booking"
    booking = @alpha.bookings.fetch("BK-104")
    cost = booking.cost_lines.select(&:stage_committed?).sum(&:amount_minor_units)
    commission = booking.expected_commissions.sum(&:amount_minor_units)
    row = css_select("#breakdown tbody tr").find { |tr| tr.text.include?(booking.booking_reference) }
    assert_includes row.text, Money.new(cost, "USD").format
    assert_includes row.text, Money.new(commission, "USD").format
    assert_includes row.text, Money.new(cost - commission, "USD").format
    total = CostLine.where(supplier_arrangement: @departure.supplier_arrangements).select(&:stage_committed?).sum(&:amount_minor_units)
    assert_select "#breakdown tfoot td", text: /#{Regexp.escape(Money.new(total, "USD").format)}/
  end

  test "staff who can't see supplier cost can't open the tab" do
    sign_in_as agency_users(:harbor_baseline_staff)
    get departure_supplier_money_path(@departure, view: "booking")
    assert_redirected_to root_path
  end
end
