require "test_helper"

class AlphaFixtureTest < ActiveSupport::TestCase
  setup do
    suffix = SecureRandom.hex(4)
    @agency = ProvisionAgency.new(
      name: "Alpha Fixture #{suffix}",
      workspace_code: "alpha-#{suffix}",
      country_code: "US",
      default_currency: "USD",
      default_timezone: "America/New_York",
      administrator_email: "admin-#{suffix}@example.test",
      administrator_first_name: "Pat",
      administrator_last_name: "Harbor",
      administrator_password: TEST_PASSWORD,
      actor_identifier: "test:alpha-fixture-#{suffix}"
    ).call.record
    @actor = @agency.agency_users.sole
  end

  test "loads the Alpha suppliers and Departure" do
    alpha = AlphaFixture.load!(agency: @agency, actor: @actor)

    assert_equal [ "Alpha Cruises", "Sablewater Harbor Hotel", "Shore Excursions Group" ],
      @agency.suppliers.order(:display_name).pluck(:display_name)
    assert_equal [ "cruise_line" ], alpha.suppliers.fetch(:cruise).category_assignments.pluck(:category_code)
    assert_equal [ "lodging" ], alpha.suppliers.fetch(:hotel).category_assignments.pluck(:category_code)
    assert_equal [ "activity_attraction" ], alpha.suppliers.fetch(:excursion).category_assignments.pluck(:category_code)

    departure = alpha.departure
    assert_equal "Alpha Omega", departure.name
    assert_equal Date.new(2027, 11, 6), departure.starts_on
    assert_equal Date.new(2027, 11, 13), departure.ends_on
    assert_equal "America/New_York", departure.time_zone
    assert_equal "USD", departure.operating_currency
    assert_equal "DEP-0001", departure.departure_reference
    assert_equal "on_sale", departure.summary_label
    assert departure.decision_proceed?
    assert_equal @actor, departure.default_task_owner
  end

  test "loads a confirmed arrangement for each supplier, with its inventory and the cruise rate table (step 3)" do
    alpha = AlphaFixture.load!(agency: @agency, actor: @actor)
    cruise, hotel, excursion = alpha.arrangements.values_at(:cruise, :hotel, :excursion)
    assert [ cruise, hotel, excursion ].all?(&:confirmed?)
    assert_equal %w[ARR-0001 ARR-0002 ARR-0003], [ cruise, hotel, excursion ].map(&:arrangement_reference)

    assert_equal({ "V01" => [ 3 ] * 8, "O01" => [ 3 ] * 8, "I01" => [ 3 ] * 8, "S01" => [ 4 ] * 8 },
      cruise.inventory_groups.to_h { |group| [ group.label, group.unit_shells.map(&:positions) ] })
    i01 = cruise.rate_lines.joins(:inventory_group).where(inventory_groups: { label: "I01" })
    assert_equal %w[guest_1 guest_2 guest_3 single], i01.pluck(:occupancy_position).sort
    single = i01.find_by(occupancy_position: "single")
    assert_equal [ 500_000, 65_000, 13_500, 100_000 ],
      single.values_at(:base_fare_minor_units, :non_commissionable_fees_minor_units, :taxes_minor_units, :discount_minor_units)
    s01_additional = cruise.rate_lines.joins(:inventory_group).find_by(inventory_groups: { label: "S01" }, occupancy_position: "guest_4")
    assert_equal s01_additional.base_fare_minor_units, s01_additional.discount_minor_units, "S01's additional-guest discount waives the base fare"
    assert_equal 17, cruise.rate_lines.count
    assert cruise.rate_lines.all? { |line| line.commission_rate == 14 }

    groups = hotel.inventory_groups.index_by(&:label)
    assert_equal 10, groups.size
    assert_equal [ 2 ] * 4, groups.fetch("Nov 5 Garden Queen").unit_shells.map(&:positions)
    assert_equal [ 4 ] * 4, groups.fetch("Nov 5 Harbor Double").unit_shells.map(&:positions)
    assert_equal [ 2, 1 ], [ "Nov 4 Garden Queen", "Nov 4 Harbor Double" ].map { |label| groups.fetch(label).capacity_projection.current_supplier_capacity }
    assert groups.fetch("Nov 1 Garden Queen").promise_on_request?
    assert_nil groups.fetch("Nov 1 Garden Queen").capacity_projection

    tour = excursion.inventory_groups.sole
    assert_equal [ 10 ], tour.unit_shells.map(&:positions)
    assert_equal [ "Child 0–4" ], tour.capacity_rules.map { |rule| rule.traveler_type.name }
  end

  test "can stop with the Alpha arrangement in Draft, then confirm it on a later load (D1)" do
    draft = AlphaFixture.load!(agency: @agency, actor: @actor, confirm_cruise: false).arrangements.fetch(:cruise)
    assert draft.draft?
    assert_equal 0, UnitShell.where(inventory_group: draft.inventory_groups).count
    assert alpha_arrangements_confirmed_except_cruise?

    confirmed = AlphaFixture.load!(agency: @agency, actor: @actor).arrangements.fetch(:cruise)
    assert_equal draft, confirmed
    assert confirmed.confirmed?
    assert_equal 32, UnitShell.where(inventory_group: confirmed.inventory_groups).count
  end

  test "loading twice reuses the records" do
    first = AlphaFixture.load!(agency: @agency, actor: @actor)
    second = AlphaFixture.load!(agency: @agency, actor: @actor)

    assert_equal 3, @agency.suppliers.count
    assert_equal 1, @agency.departures.count
    assert_equal first.departure, second.departure
    assert_equal 1, second.departure.decisions.count
    assert_equal first.suppliers.transform_values(&:id), second.suppliers.transform_values(&:id)
    assert_equal first.arrangements.transform_values(&:id), second.arrangements.transform_values(&:id)
    assert_equal 3, @agency.supplier_arrangements.count
    assert_equal 3, PayeeAccount.where(agency: @agency).count
    assert_equal 32 + 8 + 1, UnitShell.where(agency: @agency).count
  end

  private

  def alpha_arrangements_confirmed_except_cruise?
    @agency.supplier_arrangements.where.not(status: "confirmed").map { |arrangement| arrangement.supplier.display_name } == [ "Alpha Cruises" ]
  end
end
