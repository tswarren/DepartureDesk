require "test_helper"

# SUP-35, SMN-32, D-75, FIN-03: proposals from the Alpha rate table (B6).
class ProposeBookingSupplierCostTest < ActiveSupport::TestCase
  setup do
    @agency = agencies(:harbor)
    @admin = agency_users(:harbor_admin)
    @alpha = AlphaFixture.load!(agency: @agency, actor: @admin)
    @cruise = @alpha.arrangements.fetch(:cruise)
    @adult = traveler_types(:harbor_adult)
    @infant = traveler_types(:harbor_child_0_4)
  end

  test "BK-101: three guests in V01 use the 1st, 2nd and additional-guest rows" do
    proposal = propose("V01", [ @adult ] * 3)
    assert_equal %w[guest_1 guest_2 guest_3], proposal.lines.map(&:occupancy_position)
    assert_equal [ 326_000, 326_000, 121_000 ], proposal.lines.map(&:gross)
    assert_equal 773_000, proposal.gross
    assert_equal 108_500, proposal.commission, "14% of each base fare before discount"
    assert_equal 664_500, proposal.net
    assert proposal.complete?
    assert_equal "USD", proposal.currency
  end

  test "BK-104: S01's additional-guest discount waives the base fare" do
    proposal = propose("S01", [ @adult, @adult, @adult, @infant ])
    assert_equal [ 496_000, 496_000, 46_000, 46_000 ], proposal.lines.map(&:gross)
    assert_equal [ 77_000, 77_000, 14_000, 14_000 ], proposal.lines.map(&:commission)
  end

  test "BK-103: one guest pays the full single fare, with taxes once" do
    proposal = propose("I01", [ @adult ])
    line = proposal.lines.sole
    assert_equal "single", line.occupancy_position
    assert_equal [ 500_000, 65_000, 13_500, 100_000 ], [ line.base_fare, line.non_commissionable_fees, line.taxes, line.discount ]
    assert_equal 478_500, line.gross
    assert_equal 70_000, line.commission
  end

  test "a traveler-type row wins over the row for any type, and a missing position is reported" do
    draft = draft_arrangement_with_group(positions: 2)
    group = draft.inventory_groups.sole
    save_rate!(draft, group, "guest_2", base_fare: "1000", commission_rate: "10")
    save_rate!(draft, group, "guest_2", base_fare: "0", traveler_type_id: @infant.id)

    assert_equal [ 0 ], ProposeBookingSupplierCost.new(group:, guests: [ @adult, @infant ]).call.lines.map(&:gross)
    proposal = ProposeBookingSupplierCost.new(group:, guests: [ @adult, @adult ]).call
    assert_equal [ 100_000 ], proposal.lines.map(&:gross)
    assert_equal [ "guest_1" ], proposal.missing
    assert_not proposal.complete?
  end

  test "commission on base fare less discount, a stated amount, and half-up rounding" do
    draft = draft_arrangement_with_group(positions: 3)
    group = draft.inventory_groups.sole
    save_rate!(draft, group, "guest_1", base_fare: "3500", discount: "700", commission_rate: "14", commission_base: "base_fare_less_discount")
    save_rate!(draft, group, "guest_2", base_fare: "100", commission_amount: "12.34")
    save_rate!(draft, group, "guest_3", base_fare: "3.33", commission_rate: "12.5")

    commissions = ProposeBookingSupplierCost.new(group:, guests: [ @adult ] * 3).call.lines.map(&:commission)
    assert_equal [ 39_200, 1_234, 42 ], commissions, "12.5% of 333 minor units is 41.625, rounded half up to 42"
  end

  private

  def propose(label, guests)
    ProposeBookingSupplierCost.new(group: @cruise.inventory_groups.find_by!(label:), guests:).call
  end

  def draft_arrangement_with_group(positions:)
    supplier = CreateSupplier.new(agency: @agency, actor: @admin, kind: "organization", names: { display_name: "Proposal Line" }, categories: [ "cruise_line" ]).call.record
    arrangement = CreateSupplierArrangement.new(agency: @agency, actor: @admin, departure: @alpha.departure, supplier_id: supplier.id).call.record
    SaveInventoryGroup.new(agency: @agency, actor: @admin, departure: @alpha.departure, arrangement:,
      attributes: { label: "X01", service_category: "cruise", quantity: "1", positions_per_unit: positions.to_s }).call
    arrangement
  end

  def save_rate!(arrangement, group, position, **amounts)
    SaveSupplierRateLine.new(agency: @agency, actor: @admin, departure: @alpha.departure, arrangement:,
      attributes: { inventory_group_id: group.id, occupancy_position: position, **amounts }).call
  end
end
