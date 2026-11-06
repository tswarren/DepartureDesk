require "test_helper"

# BKG-13 to BKG-16, BKG-21, BKG-23.
class OfferingCommandsTest < ActiveSupport::TestCase
  setup do
    @agency = agencies(:harbor)
    @admin = agency_users(:harbor_admin)
    @alpha = AlphaFixture.load!(agency: @agency, actor: @admin)
    @departure = @alpha.departure
    @cruise = @alpha.arrangements.fetch(:cruise)
    @v01 = @cruise.inventory_groups.find_by!(label: "V01")
    @offering = SaveOffering.new(agency: @agency, actor: @admin, departure: @departure, attributes: { name: "Test package" }).call.record
  end

  test "an offering takes the Departure's currency and is audited against the Departure" do
    assert_equal "USD", @offering.currency
    assert AuditEvent.exists?(subject_id: @departure.id, action: "departure.offering_created")
    duplicate = assert_raises(AgencyCommand::Error) { SaveOffering.new(agency: @agency, actor: @admin, departure: @departure, attributes: { name: "Test package" }).call }
    assert_match(/already has a package/, duplicate.message)
  end

  test "optional multiple applies only to add-ons, in the model and the database (BKG-14)" do
    error = assert_raises(AgencyCommand::Error) { choice!(name: "Cabin", role: "included", scope: "per_unit", pattern: "optional_multiple") }
    assert_match(/only to add-ons/, error.message)

    choice = choice!(name: "Cabin", role: "included", scope: "per_unit", pattern: "required_single")
    assert_raises(ActiveRecord::StatementInvalid) do
      OfferingChoice.transaction(requires_new: true) { OfferingChoice.where(id: choice.id).update_all(pattern: "optional_multiple") }
    end
  end

  test "an option draws on this Departure's inventory only, in the command and the database (BKG-13)" do
    choice = choice!(name: "Cabin", role: "included", scope: "per_unit", pattern: "required_single")
    option = option!(choice, label: "Veranda", inventory_group_id: @v01.id)
    assert_equal @v01, option.inventory_group

    other = CreateDeparture.new(agency: @agency, actor: @admin, attributes: { name: "Elsewhere", operating_currency: "USD" }).call.record
    supplier = CreateSupplier.new(agency: @agency, actor: @admin, kind: "organization", names: { display_name: "Elsewhere Line" }, categories: [ "cruise_line" ]).call.record
    elsewhere = CreateSupplierArrangement.new(agency: @agency, actor: @admin, departure: other, supplier_id: supplier.id).call.record
    foreign_group = SaveInventoryGroup.new(agency: @agency, actor: @admin, departure: other, arrangement: elsewhere, attributes: { label: "X", service_category: "cruise" }).call.record

    assert_match(/this departure's arrangements/, assert_raises(AgencyCommand::Error) { option!(choice, label: "X", inventory_group_id: foreign_group.id) }.message)
    assert_raises(ActiveRecord::StatementInvalid) do
      OfferingOption.transaction(requires_new: true) { OfferingOption.where(id: option.id).update_all(inventory_group_id: foreign_group.id) }
    end
  end

  test "prices are set per position and traveler type, strictly parsed, and looked up with fallbacks (BKG-21)" do
    choice = choice!(name: "Cabin", role: "included", scope: "per_unit", pattern: "required_single")
    option = option!(choice, label: "Veranda", inventory_group_id: @v01.id)
    price!(option, "guest_1", "3,385")
    price!(option, "any", "1285")
    child = price!(option, "any", "0", traveler_type_id: traveler_types(:harbor_child_0_4).id)

    lookup = OfferingPriceLookup.new(option: option.reload)
    assert_equal 338_500, lookup.price_for(occupancy_position: "guest_1").amount_minor_units
    assert_equal 338_500, lookup.price_for(occupancy_position: "single").amount_minor_units, "a lone guest takes the 1st-guest price without a single price"
    assert_equal 128_500, lookup.price_for(occupancy_position: "guest_3", traveler_type: traveler_types(:harbor_adult)).amount_minor_units
    assert_equal child, lookup.price_for(occupancy_position: "guest_3", traveler_type: traveler_types(:harbor_child_0_4))
    assert_equal 338_500, lookup.price_for(occupancy_position: "guest_1", traveler_type: traveler_types(:harbor_child_0_4)).amount_minor_units,
      "a position row comes before an any-position row for the type"

    assert_match(/must be an amount in USD/, assert_raises(AgencyCommand::Error) { price!(option, "guest_2", "12.345") }.message)
    assert_match(/beyond V01's 3 positions/, assert_raises(AgencyCommand::Error) { price!(option, "guest_4", "1") }.message)

    price!(option, "guest_1", "3400")
    set = AuditEvent.where(subject_id: @departure.id, action: "departure.offering_price_set").order(:created_at).last
    assert_equal [ 340_000, 338_500 ], set.details.values_at("amount_minor_units", "previous_amount_minor_units")
  end

  test "an offering lists what it still needs before it can be booked" do
    cabin = choice!(name: "Cabin", role: "included", scope: "per_unit", pattern: "required_single")
    tour = choice!(name: "Tour", role: "add_on", scope: "per_traveler", pattern: "optional_single")
    assert_equal [ "Add an option to Cabin." ], @offering.reload.booking_blockers

    option = option!(cabin, label: "Veranda", inventory_group_id: @v01.id)
    assert_equal [ "Set the single occupancy price for Veranda.", "Set the 1st guest price for Veranda.",
                   "Set the 2nd guest price for Veranda.", "Set the 3rd guest price for Veranda." ], @offering.reload.booking_blockers
    price!(option, "single", "6635")
    price!(option, "any", "3385")
    excursion = @alpha.arrangements.fetch(:excursion).inventory_groups.sole
    tour_option = option!(tour, label: "Miami", inventory_group_id: excursion.id)
    assert_equal [ "Set the any position price for Miami." ], @offering.reload.booking_blockers
    price!(tour_option, "any", "150")
    assert_empty @offering.reload.booking_blockers
  end

  test "removing a choice removes its options and prices; editing needs Departure management" do
    choice = choice!(name: "Cabin", role: "included", scope: "per_unit", pattern: "required_single")
    price!(option!(choice, label: "Veranda", inventory_group_id: @v01.id), "any", "1")
    RemoveOfferingChoice.new(agency: @agency, actor: @admin, departure: @departure, offering: @offering, choice:).call
    assert_empty OfferingOption.where(offering_choice_id: choice.id)

    refused = assert_raises(AgencyCommand::Error) do
      SaveOfferingChoice.new(agency: @agency, actor: agency_users(:harbor_baseline_staff), departure: @departure, offering: @offering,
        attributes: { name: "X", role: "add_on", scope: "per_trip", pattern: "optional_single" }).call
    end
    assert_equal :unauthorized, refused.code
    assert_raises(ActiveRecord::RecordNotFound) do
      SaveOffering.new(agency: agencies(:cove), actor: agency_users(:cove_admin), departure: @departure, offering: @offering, attributes: { name: "X" }, lock_version: 0).call
    end
  end

  private

  def choice!(**attributes)
    SaveOfferingChoice.new(agency: @agency, actor: @admin, departure: @departure, offering: @offering, attributes:).call.record
  end

  def option!(choice, **attributes)
    SaveOfferingOption.new(agency: @agency, actor: @admin, departure: @departure, offering: @offering, choice:, attributes:).call.record
  end

  def price!(option, position, amount, traveler_type_id: nil)
    SaveOfferingPrice.new(agency: @agency, actor: @admin, departure: @departure, offering: @offering, option:,
      attributes: { occupancy_position: position, amount:, traveler_type_id: }).call.record
  end
end
