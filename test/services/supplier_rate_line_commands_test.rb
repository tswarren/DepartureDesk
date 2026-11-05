require "test_helper"

# SUP-35, D-75, INV-09, ADR 0001 and ADR 0018.
class SupplierRateLineCommandsTest < ActiveSupport::TestCase
  setup do
    set_clock Time.utc(2026, 11, 10, 15)
    @agency = agencies(:harbor)
    @admin = agency_users(:harbor_admin)
    @departure = CreateDeparture.new(agency: @agency, actor: @admin, attributes: { name: "Rates", operating_currency: "USD", time_zone: "America/New_York" }).call.record
    supplier = CreateSupplier.new(agency: @agency, actor: @admin, kind: "organization", names: { display_name: "Rate Supplier" }, categories: [ "cruise_line" ]).call.record
    payee = SavePayeeAccount.new(agency: @agency, actor: @admin, supplier:, attributes: { name: "USD", currency: "USD" }).call.record
    @arrangement = CreateSupplierArrangement.new(agency: @agency, actor: @admin, departure: @departure, supplier_id: supplier.id,
      attributes: { group_reference: "GRP-1", payee_account_id: payee.id }).call.record
    @cabins = SaveInventoryGroup.new(agency: @agency, actor: @admin, departure: @departure, arrangement: @arrangement, attributes: {
      label: "I01", service_category: "cruise", quantity: "8", positions_per_unit: "3", starts_on: "2027-11-06", ends_on: "2027-11-13", time_zone: "America/New_York"
    }).call.record
  end

  test "staff enter each component as stated, parsed strictly into minor units, with an audit entry" do
    line = save!(occupancy_position: "guest_1", base_fare: "1,850.00", non_commissionable_fees: "245", taxes: "189.5", commission_rate: "14").record
    assert_equal [ 185_000, 24_500, 18_950, 0 ], line.values_at(:base_fare_minor_units, :non_commissionable_fees_minor_units, :taxes_minor_units, :discount_minor_units)
    assert_equal BigDecimal("14"), line.commission_rate
    assert_nil line.commission_minor_units
    assert_equal "USD", line.currency
    added = AuditEvent.where(subject_id: @arrangement.id, action: "supplier_arrangement.rate_line_added").sole
    assert_equal line.id, added.details["supplier_rate_line_id"]

    save!(rate_line: line, occupancy_position: "guest_1", base_fare: "1850", discount: "100", commission_rate: "14")
    assert_equal 10_000, line.reload.discount_minor_units
    assert_equal %w[discount_minor_units non_commissionable_fees_minor_units taxes_minor_units],
      AuditEvent.where(subject_id: @arrangement.id, action: "supplier_arrangement.rate_line_updated").sole.details["changed"]
  end

  test "an amount that is ambiguous or would round is refused, not changed" do
    [ "12.345", "-5", "$5", "1.2.3", "1,23" ].each do |entry|
      error = assert_raises(AgencyCommand::Error, entry) { save!(occupancy_position: "guest_1", base_fare: entry) }
      assert_equal :invalid, error.code
      assert_match(/\ABase fare must be an amount in USD/, error.message)
    end
    assert_match(/Base fare is required/, assert_raises(AgencyCommand::Error) { save!(occupancy_position: "guest_1", base_fare: "") }.message)
    assert_match(/Commission rate/, assert_raises(AgencyCommand::Error) { save!(occupancy_position: "guest_1", base_fare: "1", commission_rate: "101") }.message)
    assert_empty @arrangement.rate_lines
  end

  test "commission is a rate or an amount, never both, in the model and the database" do
    error = assert_raises(AgencyCommand::Error) { save!(occupancy_position: "guest_1", base_fare: "100", commission_rate: "10", commission_amount: "10") }
    assert_match(/not both/, error.message)

    line = save!(occupancy_position: "guest_1", base_fare: "100", commission_amount: "10").record
    assert_raises(ActiveRecord::StatementInvalid) do
      SupplierRateLine.transaction(requires_new: true) { SupplierRateLine.where(id: line.id).update_all(commission_rate: 10) }
    end
  end

  test "one rate per group, occupancy position and traveler type, within the unit's positions (INV-09)" do
    save!(occupancy_position: "guest_2", base_fare: "900")
    duplicate = assert_raises(AgencyCommand::Error) { save!(occupancy_position: "guest_2", base_fare: "800") }
    assert_match(/already has a rate/, duplicate.message)
    child = save!(occupancy_position: "guest_2", base_fare: "0", traveler_type_id: traveler_types(:harbor_child_0_4).id).record
    assert_equal traveler_types(:harbor_child_0_4), child.traveler_type

    beyond = assert_raises(AgencyCommand::Error) { save!(occupancy_position: "guest_4", base_fare: "500") }
    assert_match(/Occupancy position is beyond I01's 3 positions/, beyond.message)

    other_agency = assert_raises(AgencyCommand::Error) { save!(occupancy_position: "single", base_fare: "1", traveler_type_id: traveler_types(:cove_adult).id) }
    assert_match(/agency's traveler types/, other_agency.message)
  end

  test "a rate stays in its group, and the database keeps rows in the arrangement's currency and owner" do
    line = save!(occupancy_position: "single", base_fare: "3000").record
    suite = SaveInventoryGroup.new(agency: @agency, actor: @admin, departure: @departure, arrangement: @arrangement, attributes: { label: "S01", service_category: "cruise" }).call.record
    moved = assert_raises(AgencyCommand::Error) { save!(rate_line: line, inventory_group_id: suite.id, occupancy_position: "single", base_fare: "3000") }
    assert_match(/stays in its inventory group/, moved.message)
    assert_raises(ActiveRecord::StatementInvalid) do
      SupplierRateLine.transaction(requires_new: true) { SupplierRateLine.where(id: line.id).update_all(currency: "EUR") }
    end
    other = CreateSupplierArrangement.new(agency: @agency, actor: @admin, departure: @departure,
      supplier_id: CreateSupplier.new(agency: @agency, actor: @admin, kind: "organization", names: { display_name: "Other" }, categories: [ "cruise_line" ]).call.record.id).call.record
    assert_raises(ActiveRecord::StatementInvalid) do
      SupplierRateLine.transaction(requires_new: true) { SupplierRateLine.where(id: line.id).update_all(supplier_arrangement_id: other.id) }
    end
  end

  test "Confirm freezes the table: commands refuse it and the database rejects any change (ADR 0018)" do
    line = save!(occupancy_position: "guest_1", base_fare: "1850").record
    confirm!
    assert_equal 1, AuditEvent.where(subject_id: @arrangement.id, action: "supplier_arrangement.confirmed").sole.details["rate_lines_frozen"]

    assert_equal :invalid_state, assert_raises(AgencyCommand::Error) { save!(rate_line: line, occupancy_position: "guest_1", base_fare: "1") }.code
    assert_equal :invalid_state, assert_raises(AgencyCommand::Error) { save!(occupancy_position: "guest_2", base_fare: "1") }.code
    assert_equal :invalid_state, assert_raises(AgencyCommand::Error) { remove!(line) }.code

    assert_raises(ActiveRecord::StatementInvalid) { SupplierRateLine.transaction(requires_new: true) { SupplierRateLine.where(id: line.id).update_all(base_fare_minor_units: 1) } }
    assert_raises(ActiveRecord::StatementInvalid) { SupplierRateLine.transaction(requires_new: true) { SupplierRateLine.where(id: line.id).delete_all } }
    assert_raises(ActiveRecord::StatementInvalid) do
      SupplierRateLine.transaction(requires_new: true) do
        SupplierRateLine.insert_all!([ { agency_id: @agency.id, supplier_arrangement_id: @arrangement.id, inventory_group_id: @cabins.id,
                                        occupancy_position: "guest_2", currency: "USD", base_fare_minor_units: 1 } ])
      end
    end
    assert_equal 185_000, line.reload.base_fare_minor_units
  end

  test "Confirm is blocked by a rate beyond a group's positions after the group shrinks" do
    save!(occupancy_position: "guest_3", base_fare: "500")
    SaveInventoryGroup.new(agency: @agency, actor: @admin, departure: @departure, arrangement: @arrangement, group: @cabins,
      attributes: { positions_per_unit: "2" }, lock_version: @cabins.reload.lock_version).call
    error = assert_raises(AgencyCommand::Error) { confirm! }
    assert_match(/Remove the guest 3 rate for I01; it has 2 positions/, error.message)
  end

  test "removing a rate or a Draft group removes its rows, with an audit entry" do
    line = save!(occupancy_position: "guest_1", base_fare: "1850").record
    remove!(line)
    assert_empty @arrangement.rate_lines.reload
    assert AuditEvent.exists?(subject_id: @arrangement.id, action: "supplier_arrangement.rate_line_removed")

    save!(occupancy_position: "guest_1", base_fare: "1850")
    RemoveInventoryGroup.new(agency: @agency, actor: @admin, departure: @departure, arrangement: @arrangement, group: @cabins).call
    assert_empty @arrangement.rate_lines.reload
  end

  test "only Supplier arrangements may change the rate table" do
    [ :harbor_staff, :harbor_baseline_staff ].each do |user|
      error = assert_raises(AgencyCommand::Error, user.to_s) do
        SaveSupplierRateLine.new(agency: @agency, actor: agency_users(user), departure: @departure, arrangement: @arrangement,
          attributes: { inventory_group_id: @cabins.id, occupancy_position: "guest_1", base_fare: "1" }).call
      end
      assert_equal :unauthorized, error.code
    end
  end

  private

  def save!(rate_line: nil, **attributes)
    SaveSupplierRateLine.new(agency: @agency, actor: @admin, departure: @departure, arrangement: @arrangement, rate_line:,
      attributes: { inventory_group_id: @cabins.id, **attributes }, lock_version: rate_line&.reload&.lock_version).call
  end

  def remove!(line)
    RemoveSupplierRateLine.new(agency: @agency, actor: @admin, departure: @departure, arrangement: @arrangement, rate_line: line).call
  end

  def confirm!
    ConfirmSupplierArrangement.new(agency: @agency, actor: @admin, departure: @departure, arrangement: @arrangement,
      confirmed_on: "2026-11-09", lock_version: @arrangement.reload.lock_version).call
  end
end
