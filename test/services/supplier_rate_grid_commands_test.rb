require "test_helper"

# The supplier rate grid (S-14, SUP-35): patterns, bands, shared values,
# per-fare overrides, copying, and the freeze at confirmation (ADR 0018).
class SupplierRateGridCommandsTest < ActiveSupport::TestCase
  setup do
    @agency = agencies(:harbor)
    @admin = agency_users(:harbor_admin)
    @alpha = AlphaFixture.load!(agency: @agency, actor: @admin, confirm_cruise: false)
    @departure = @alpha.departure
    @cruise = @alpha.arrangements.fetch(:cruise)
    @groups = @cruise.inventory_groups.index_by(&:label)
  end

  test "the Alpha grid stores one line per position, with shared values and the single fares' own port charges" do
    v01 = @cruise.rate_lines.where(inventory_group: @groups.fetch("V01")).index_by(&:occupancy_position)
    assert_equal %w[guest_1 guest_2 guest_3 single], v01.keys.sort
    assert_equal [ 350_000, 70_000, 32_500, 13_500, BigDecimal("14") ], v01.fetch("guest_2").values_at(:base_fare_minor_units, :discount_minor_units,
      :non_commissionable_fees_minor_units, :taxes_minor_units, :commission_rate)
    assert_equal [ 700_000, 65_000, [ "non_commissionable_fees" ] ], v01.fetch("single").values_at(:base_fare_minor_units, :non_commissionable_fees_minor_units, :overridden_fields)
    assert_equal [ "1st and 2nd guest", "3rd and 4th guest", "Single" ], @cruise.rate_bands.map(&:label)
    assert_equal "cruise_bands", @cruise.reload.rate_pattern
  end

  test "changing a shared value changes every fare that doesn't override it" do
    save!(defaults: { "taxes" => "150" })
    lines = @cruise.rate_lines.reload
    assert lines.all? { |line| line.taxes_minor_units == 15_000 }
    assert lines.select { |line| line.occupancy_position == "single" }.all? { |line| line.non_commissionable_fees_minor_units == 65_000 }
  end

  test "a dollar commission keeps only the amount; a fare may use its own commission method" do
    s01 = @groups.fetch("S01")
    single = band("Single")
    save!(defaults: { "commission_method" => "amount", "commission_amount" => "490", "commission_rate" => "14" },
      overrides: { SupplierRateGrid.cell_key(s01, single) => { "commission_method" => "percent", "commission_rate" => "10", "commission_base" => "base_fare_less_discount" } })
    v01 = @cruise.rate_lines.find_by!(inventory_group: @groups.fetch("V01"), occupancy_position: "guest_1")
    assert_equal [ nil, 49_000 ], v01.values_at(:commission_rate, :commission_minor_units)
    assert_equal [ "amount", nil, nil, 49_000 ], @cruise.reload.values_at(:rate_commission_method, :rate_commission_rate, :rate_commission_base, :rate_commission_minor_units),
      "the rate typed before switching to a dollar amount isn't kept"
    s01_single = @cruise.rate_lines.find_by!(inventory_group: s01, occupancy_position: "single")
    assert_equal [ BigDecimal("10"), "base_fare_less_discount", nil ], s01_single.values_at(:commission_rate, :commission_base, :commission_minor_units)
    assert_includes s01_single.overridden_fields, "commission"
  end

  test "a blank fare removes that cell's lines, and a refused save changes nothing" do
    i01 = @groups.fetch("I01")
    save!(blank: SupplierRateGrid.cell_key(i01, band("Single")))
    assert_nil @cruise.rate_lines.find_by(inventory_group: i01, occupancy_position: "single")

    before = @cruise.rate_lines.reload.map(&:attributes)
    refused = assert_raises(AgencyCommand::Error) { save!(fare: { SupplierRateGrid.cell_key(i01, band("1st and 2nd guest")) => "2,500.555" }) }
    assert_match(/I01, 1st and 2nd guest: the fare must be an amount in USD/, refused.message)
    assert_equal before, @cruise.rate_lines.reload.map(&:attributes)
  end

  test "patterns keep each position's fare; custom bands add a traveler-type fare and refuse overlaps" do
    SetSupplierRatePattern.new(agency: @agency, actor: @admin, departure: @departure, arrangement: @cruise, pattern: "per_guest").call
    assert_equal [ "1st guest", "2nd guest", "3rd guest", "4th guest", "Single" ], @cruise.rate_bands.reload.map(&:label)
    grid = SupplierRateGrid.new(@cruise.reload)
    assert_equal "750", grid.cell(@groups.fetch("V01"), @cruise.rate_bands.find_by!(label: "3rd guest")).fare

    SetSupplierRatePattern.new(agency: @agency, actor: @admin, departure: @departure, arrangement: @cruise, pattern: "cruise_bands").call
    SetSupplierRatePattern.new(agency: @agency, actor: @admin, departure: @departure, arrangement: @cruise, pattern: "custom").call
    child = @agency.traveler_types.find_by!(name: "Child 0–4")
    added = SaveSupplierRateBand.new(agency: @agency, actor: @admin, departure: @departure, arrangement: @cruise,
      attributes: { positions: %w[guest_3 guest_4], traveler_type_id: child.id }).call.record
    assert_equal "Child 0–4, 3rd and 4th", added.label
    overlap = assert_raises(AgencyCommand::Error) do
      SaveSupplierRateBand.new(agency: @agency, actor: @admin, departure: @departure, arrangement: @cruise, attributes: { positions: %w[guest_2 guest_3] }).call
    end
    assert_match(/overlap the 1st and 2nd guest band/, overlap.message)

    save!(fare: { SupplierRateGrid.cell_key(@groups.fetch("S01"), added) => "0" })
    assert_equal 2, @cruise.rate_lines.where(traveler_type: child).count
    RemoveSupplierRateBand.new(agency: @agency, actor: @admin, departure: @departure, arrangement: @cruise, band: added).call
    assert_equal 0, @cruise.rate_lines.where(traveler_type: child).count
  end

  test "rates copy from another arrangement of the same supplier, matching groups by name" do
    other = CreateDeparture.new(agency: @agency, actor: @admin, attributes: { name: "Spring sampler", operating_currency: "USD" }).call.record
    copy = CreateSupplierArrangement.new(agency: @agency, actor: @admin, departure: other, supplier_id: @cruise.supplier_id).call.record
    %w[V01 S01 X99].each do |label|
      SaveInventoryGroup.new(agency: @agency, actor: @admin, departure: other, arrangement: copy,
        attributes: { label:, service_category: "cruise", representation: "unit_shells", quantity: 2, positions_per_unit: label == "S01" ? 4 : 3 }).call
    end
    assert_includes CopySupplierRates.sources(@agency, copy), @cruise

    result = CopySupplierRates.new(agency: @agency, actor: @admin, departure: other, arrangement: copy, source_id: @cruise.id).call.record
    assert_equal [ 9, 8 ], [ result[:copied], result[:skipped] ], "V01's 4 and S01's 5 copy; O01's and I01's have no group"
    assert_equal [ "cruise_bands", 14 ], [ copy.reload.rate_pattern, copy.rate_commission_rate.to_i ]
    assert_equal 700_000, copy.rate_lines.find_by!(occupancy_position: "single", inventory_group: copy.inventory_groups.find_by!(label: "V01")).base_fare_minor_units
  end

  test "confirming the arrangement freezes the grid, in the commands and the database (ADR 0018)" do
    confirm!
    refused = assert_raises(AgencyCommand::Error) { save!(defaults: { "taxes" => "1" }) }
    assert_equal :invalid_state, refused.code
    assert_raises(AgencyCommand::Error) { SetSupplierRatePattern.new(agency: @agency, actor: @admin, departure: @departure, arrangement: @cruise, pattern: "per_guest").call }
    assert_raises(ActiveRecord::StatementInvalid) do
      SupplierRateBand.transaction(requires_new: true) { SupplierRateBand.where(supplier_arrangement_id: @cruise.id).update_all(label: "Changed") }
    end
  end

  test "only Supplier arrangements may change the rates" do
    refused = assert_raises(AgencyCommand::Error) do
      SetSupplierRatePattern.new(agency: @agency, actor: agency_users(:harbor_staff), departure: @departure, arrangement: @cruise, pattern: "per_guest").call
    end
    assert_equal :unauthorized, refused.code
  end

  private

  def band(label) = @cruise.rate_bands.reload.find_by!(label:)

  # Resaves the Alpha grid as displayed, with the given changes.
  def save!(defaults: {}, fare: {}, blank: nil, overrides: {})
    grid = SupplierRateGrid.new(@cruise.reload)
    cells = grid.groups.flat_map { |group| grid.cells_for(group) }.select(&:available).to_h do |cell|
      [ cell.key, { "fare" => cell.key == blank ? "" : fare.fetch(cell.key, cell.fare), "discount" => cell.discount,
                    "override" => cell.overrides.merge(overrides.fetch(cell.key, {})) } ]
    end
    SaveSupplierRates.new(agency: @agency, actor: @admin, departure: @departure, arrangement: @cruise, defaults: grid.defaults.merge(defaults), cells:).call
  end

  def confirm!
    ConfirmSupplierArrangement.new(agency: @agency, actor: @admin, departure: @departure, arrangement: @cruise.reload,
      confirmed_on: AlphaFixture::CONFIRMED_ON, lock_version: @cruise.lock_version).call
    @cruise.reload
  end
end
