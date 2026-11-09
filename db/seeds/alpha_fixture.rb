# The Alpha fixture (first-slice charter, Fixture; D-87), loaded by one script
# for development (db/seeds.rb) and for the demonstration-case tests. All names
# are fictional.
#
# Seeds what the app can hold so far: the three suppliers and the Departure,
# which has the loading user as its default task owner, a Proceed decision
# and the Ready to sell status (step 2); and a payee account and a confirmed
# arrangement for each supplier, with their inventory groups, the excursion's
# Child 0–4 capacity rule, the Alpha cruise rate table, and the Agreement A
# deadlines, each with a task for the default task owner (step 3); and, once
# each arrangement is confirmed, its supplier cost and schedule (step 4); and
# the Alpha Omega cruise package with its client prices, the client terms
# and the agency's terms defaults (step 5); and, with bookings: :trips, the
# Slice 1 roster's clients, travelers and Client Trips (step 6a, D-94); and,
# with bookings: :held, a held booking on each trip (step 6b, D-95), and with
# bookings: :confirmed, each accepted and confirmed at its roster date (step
# 6c, D-94). Each
# Slice 1 step extends this script with the records it builds.
# Loading is idempotent: records already present in the agency are reused.
# Pass confirm_cruise: false to stop with the Alpha arrangement in Draft (D1).
module AlphaFixture
  Result = Data.define(:agency, :actor, :suppliers, :departure, :arrangements, :offering, :client_terms, :trips, :bookings)
  BOOKING_LEVELS = %i[none trips held confirmed paid].freeze

  DEPARTURE_NAME = "Alpha Omega"
  DEPARTURE_DESCRIPTION = "Port Everglades round trip."
  STARTS_ON = Date.new(2027, 11, 6)
  ENDS_ON = Date.new(2027, 11, 13)
  TIME_ZONE = "America/New_York"
  CURRENCY = "USD"

  SUPPLIERS = {
    cruise: { display_name: "Alpha Cruises", categories: [ "cruise_line" ] },
    hotel: { display_name: "Sablewater Harbor Hotel", categories: [ "lodging" ] },
    excursion: { display_name: "Shore Excursions Group", categories: [ "activity_attraction" ] }
  }.freeze

  # Group references and confirmation dates are placeholders: the fixture
  # doesn't settle the cruise group number, and Oct 1, 2026 is the Alpha
  # Cruises contract date, used for all three.
  CONFIRMED_ON = Date.new(2026, 10, 1)
  CRUISE_DATES = { starts_on: STARTS_ON, starts_at_time: "16:00", ends_on: ENDS_ON, ends_at_time: "07:00", time_zone: TIME_ZONE }.freeze

  # Agreement A. Per guest by occupancy position: base fare, discount, and for
  # the 3rd and 4th guest the additional-guest base fare and discount. NCCF and
  # taxes are the same for every category. Commission is 14% of the base fare
  # before the discount, and single occupancy is a full single fare: the
  # 1st-guest fare plus the supplement, which repeats the base fare, NCCF and
  # discount but not the taxes (B6, D-87).
  CRUISE_CABINS = [
    { label: "V01", positions: 3, base: 3_500, discount: 700, additional_base: 750, additional_discount: 0 },
    { label: "O01", positions: 3, base: 3_000, discount: 600, additional_base: 600, additional_discount: 0 },
    { label: "I01", positions: 3, base: 2_500, discount: 500, additional_base: 450, additional_discount: 0 },
    { label: "S01", positions: 4, base: 5_500, discount: 1_000, additional_base: 1_000, additional_discount: 1_000 }
  ].freeze
  CRUISE_NCCF = 325
  CRUISE_TAXES = 135
  CRUISE_COMMISSION_RATE = "14"

  # B4: one group per room type and night. Nov 5 and Nov 4 are firm; Nov 1-3
  # are on request with no balance. Rooms hold 2 (Garden Queen) or 4 (Harbor
  # Double) guests, so BK-101's three travelers need two Garden Queen rooms.
  # B4: the firm rooms entered as committed cost, $1,280 for Nov 5 and $465
  # for Nov 4.
  HOTEL_FIRM_ROOMS = {
    "Nov 5 Garden Queen" => "145", "Nov 5 Harbor Double" => "175", "Nov 4 Garden Queen" => "145", "Nov 4 Harbor Double" => "175"
  }.freeze
  HOTEL_ROOMS = { "Garden Queen" => { nov4: 2, nov5: 4, positions: 2 }, "Harbor Double" => { nov4: 1, nov5: 4, positions: 4 } }.freeze

  # Agreement A (B3, B9, B13, B14). Date-only, so each is due at 11:59 p.m.
  # agency time (SET-10).
  DEADLINES = {
    cruise: [
      { deadline_type: "deposit_payment", description: "Initial deposit, $50 per stateroom", due_on: Date.new(2026, 11, 1) },
      { deadline_type: "deposit_payment", description: "Full deposit and names for cabins not yet named", due_on: Date.new(2027, 3, 1) },
      { deadline_type: "deposit_payment", description: "Final payment", due_on: Date.new(2027, 8, 1) }
    ],
    hotel: [
      { deadline_type: "deposit_payment", description: "Payment in full at checkout", due_on: Date.new(2027, 11, 6) }
    ],
    excursion: [
      { deadline_type: "final_count", description: "Final count", due_on: Date.new(2027, 10, 22) },
      { deadline_type: "deposit_payment", description: "Payment, $1,000 per confirmed resource", due_on: Date.new(2027, 10, 22) }
    ]
  }.freeze

  ARRANGEMENTS = {
    cruise: {
      payee: "Alpha Cruises group sales",
      attributes: {
        group_reference: "ALPHA-A", default_availability_promise: "firm_block",
        covered_services: "Alpha Omega, Port Everglades round trip, Nov 6–13, 2027. 8 cabins each in V01, O01, I01 and S01.",
        terms: "Agreement A. $50 per stateroom initial deposit due Nov 1, 2026, credited toward the $500 full deposit. " \
               "Full deposit for cabins not yet named due Mar 1, 2027. Final payment due Aug 1, 2027."
      }
    },
    hotel: {
      payee: "Sablewater Harbor Hotel front office",
      attributes: {
        group_reference: "SABLEWATER-ALPHA", default_availability_promise: "firm_block", obligation_shape: "committed_quantity",
        covered_services: "Garden Queen and Harbor Double rooms, Nov 1–5, 2027; Nov 5 is the included night.",
        terms: "$145 Garden Queen and $175 Harbor Double per room-night. Paid in full at checkout, Nov 6, 2027."
      }
    },
    excursion: {
      payee: "Shore Excursions Group",
      attributes: {
        group_reference: "SEG-ALPHA", default_availability_promise: "firm_block", obligation_shape: "fixed_resource_charge",
        covered_services: "Private Miami City Highlights Half Day Your Way from Fort Lauderdale (Hotel Guests), Nov 5, 2027.",
        terms: "$1,000 per resource of 10 positions, all fees included except gratuity, due with the final count. " \
               "Children 0–4 free, counted in the headcount. Final count due Oct 22, 2027 at 11:59 p.m."
      }
    }
  }.freeze

  def self.load!(agency:, actor:, confirm_cruise: true, bookings: :none)
    raise ArgumentError, "bookings must be one of #{BOOKING_LEVELS.inspect}" unless bookings.in?(BOOKING_LEVELS)

    suppliers = SUPPLIERS.transform_values { |definition| supplier!(agency, actor, definition) }
    departure = departure!(agency, actor)
    arrangements = ARRANGEMENTS.to_h do |key, definition|
      arrangement = arrangement!(agency, actor, departure, suppliers.fetch(key), definition) do |draft|
        send(:"#{key}_inventory!", agency, actor, departure, draft)
        deadlines!(agency, actor, departure, draft, DEADLINES.fetch(key))
      end
      confirm!(agency, actor, departure, arrangement) unless key == :cruise && !confirm_cruise
      arrangement.reload
      money!(agency, actor, departure, arrangement, key) if arrangement.confirmed? && arrangement.schedule_lines.none?
      [ key, arrangement.reload ]
    end
    terms_defaults!(agency, actor)
    offering = package!(agency, actor, departure, arrangements)
    client_terms = client_terms!(agency, actor, departure)
    trips = bookings == :none ? {} : roster!(agency, actor, departure)
    roster_bookings = bookings.in?(%i[held confirmed paid]) ? roster_bookings!(agency, actor, trips, confirm: bookings.in?(%i[confirmed paid])) : {}
    roster_payments!(agency, actor, roster_bookings, arrangements) if bookings == :paid
    Result.new(agency:, actor:, suppliers:, departure:, arrangements:, offering:, client_terms:, trips:, bookings: roster_bookings)
  end

  # Creates the Draft arrangement and its inventory once; later loads reuse it.
  def self.arrangement!(agency, actor, departure, supplier, definition)
    existing = departure.supplier_arrangements.live.find_by(supplier:)
    return existing if existing

    payee = supplier.payee_accounts.find_by(name: definition.fetch(:payee)) ||
      SavePayeeAccount.new(agency:, actor:, supplier:, attributes: { name: definition.fetch(:payee), currency: CURRENCY }).call.record
    arrangement = created!(
      CreateSupplierArrangement.new(agency:, actor:, departure:, supplier_id: supplier.id,
        attributes: definition.fetch(:attributes).merge(payee_account_id: payee.id)).call,
      "the #{supplier.display_name} arrangement"
    )
    yield arrangement
    arrangement
  end
  private_class_method :arrangement!

  def self.confirm!(agency, actor, departure, arrangement)
    return unless arrangement.reload.draft?

    ConfirmSupplierArrangement.new(agency:, actor:, departure:, arrangement:, confirmed_on: CONFIRMED_ON, lock_version: arrangement.lock_version).call
  end
  private_class_method :confirm!

  # The Alpha rate schedule as a rate grid (S-14): cruise bands, with port
  # charges, taxes and commission entered once. A single fare is the 1st-guest
  # fare and discount doubled, and carries double port charges (B6).
  def self.cruise_inventory!(agency, actor, departure, arrangement)
    groups = CRUISE_CABINS.to_h do |cabin|
      [ cabin, group!(agency, actor, departure, arrangement, label: cabin[:label], service_category: "cruise",
        quantity: 8, positions_per_unit: cabin[:positions], **CRUISE_DATES) ]
    end
    SetSupplierRatePattern.new(agency:, actor:, departure:, arrangement:, pattern: "cruise_bands").call
    bands = arrangement.rate_bands.reload.index_by(&:label)
    cells = groups.each_with_object({}) do |(cabin, group), all|
      all[SupplierRateGrid.cell_key(group, bands.fetch("1st and 2nd guest"))] = { fare: cabin[:base].to_s, discount: cabin[:discount].to_s }
      all[SupplierRateGrid.cell_key(group, bands.fetch("3rd and 4th guest"))] = { fare: cabin[:additional_base].to_s, discount: cabin[:additional_discount].to_s }
      all[SupplierRateGrid.cell_key(group, bands.fetch("Single"))] = {
        fare: (cabin[:base] * 2).to_s, discount: (cabin[:discount] * 2).to_s, override: { non_commissionable_fees: (CRUISE_NCCF * 2).to_s }
      }
    end
    SaveSupplierRates.new(agency:, actor:, departure:, arrangement:, cells:, defaults: {
      non_commissionable_fees: CRUISE_NCCF.to_s, taxes: CRUISE_TAXES.to_s,
      commission_method: "percent", commission_rate: CRUISE_COMMISSION_RATE, commission_base: "base_fare"
    }).call
  end
  private_class_method :cruise_inventory!

  def self.hotel_inventory!(agency, actor, departure, arrangement)
    (1..5).each do |day|
      night = Date.new(2027, 11, day)
      HOTEL_ROOMS.each do |room, counts|
        attributes = { label: "Nov #{day} #{room}", service_category: "hotel", starts_on: night, ends_on: night + 1, time_zone: TIME_ZONE }
        attributes.merge!(
          case day
          when 5 then { representation: "unit_shells", quantity: counts[:nov5], positions_per_unit: counts[:positions] }
          when 4 then { representation: "capacity_pool", quantity: counts[:nov4] }
          else { representation: "capacity_pool", availability_promise: "on_request" }
          end
        )
        group = group!(agency, actor, departure, arrangement, **attributes)
        # D-95: Child 0–4 shares a room without using one of its places.
        SetCapacityRule.new(agency:, actor:, departure:, arrangement:, group:,
          traveler_type_id: agency.traveler_types.find_by!(name: "Child 0–4").id, uses_capacity: false).call
      end
    end
  end
  private_class_method :hotel_inventory!

  # One resource of 10 positions; Child 0–4 takes part without one (INV-39).
  def self.excursion_inventory!(agency, actor, departure, arrangement)
    group = group!(agency, actor, departure, arrangement, label: "Private Miami tour", service_category: "activity",
      representation: "unit_shells", quantity: 1, positions_per_unit: 10,
      starts_on: Date.new(2027, 11, 5), starts_at_time: "14:00", ends_on: Date.new(2027, 11, 5), ends_at_time: "18:30", time_zone: TIME_ZONE)
    SetCapacityRule.new(agency:, actor:, departure:, arrangement:, group:,
      traveler_type_id: agency.traveler_types.find_by!(name: "Child 0–4").id, uses_capacity: false).call
  end
  private_class_method :excursion_inventory!

  # Client prices per guest by occupancy position: the 1st and 2nd guests,
  # each additional guest (an infant in a cabin position pays it too), and a
  # single traveler's full single fare, the 1st-guest fare plus the single
  # supplement. They give the roster's cruise subtotals (BK-101 $8,055).
  CABIN_PRICES = {
    "V01" => { first: 3_385, additional: 1_285, single: 3_385 + 3_250 },
    "O01" => { first: 2_985, additional: 1_135, single: 2_985 + 2_850 },
    "I01" => { first: 2_585, additional: 985, single: 2_585 + 2_450 },
    "S01" => { first: 5_085, additional: 535, single: 5_085 + 4_950 }
  }.freeze
  # B5: the 1st guest in a room pays; other guests pay $0.
  ROOM_PRICES = { "Garden Queen" => 190, "Harbor Double" => 220 }.freeze
  PACKAGE_NAME = "Alpha Omega cruise package"
  TERMS_WORDING = "Prices are per person in USD. Payments and cancellations follow the schedule below. These terms are fictional test terms."
  # D-93: 10% from 120 or more days before departure, 50% from 61, 100% from 0.
  CANCELLATION_TIERS = { 120 => "10", 61 => "50", 0 => "100" }.freeze

  # Placeholder agency wording and the D-93 tiers, once.
  def self.terms_defaults!(agency, actor)
    if agency.reload.client_terms_wording.blank?
      UpdateClientTermsDefaults.new(agency:, actor:, wording: TERMS_WORDING, lock_version: agency.lock_version).call
    end
    return if agency.agency_cancellation_tiers.exists?

    CANCELLATION_TIERS.each do |days, percentage|
      SaveCancellationTier.new(agency:, actor:, attributes: { min_days_before_departure: days, charge_kind: "percentage", percentage: }).call
    end
  end
  private_class_method :terms_defaults!

  # BKG-13 to BKG-16, BKG-21: the cabin per unit, the Nov 5 room included,
  # extension nights and the excursion as add-ons.
  def self.package!(agency, actor, departure, arrangements)
    existing = departure.offerings.find_by(name: PACKAGE_NAME)
    return existing if existing

    offering = created!(SaveOffering.new(agency:, actor:, departure:, attributes: {
      name: PACKAGE_NAME, description: "Seven nights on Alpha Omega from Port Everglades, with the night before at Sablewater Harbor Hotel."
    }).call, PACKAGE_NAME)
    cruise_groups = arrangements.fetch(:cruise).inventory_groups.index_by(&:label)
    hotel_groups = arrangements.fetch(:hotel).inventory_groups.index_by(&:label)

    cabin = choice!(agency, actor, departure, offering, name: "Cabin", role: "included", scope: "per_unit", pattern: "required_single")
    CABIN_PRICES.each do |label, prices|
      option = option!(agency, actor, departure, offering, cabin, label:, inventory_group_id: cruise_groups.fetch(label).id)
      { "guest_1" => prices[:first], "guest_2" => prices[:first], "any" => prices[:additional], "single" => prices[:single] }.each do |position, amount|
        price!(agency, actor, departure, offering, option, position, amount)
      end
    end

    room = choice!(agency, actor, departure, offering, name: "Nov 5 hotel room", role: "included", scope: "per_unit", pattern: "required_single")
    ROOM_PRICES.each { |type, amount| room_option!(agency, actor, departure, offering, room, type, hotel_groups.fetch("Nov 5 #{type}"), amount) }

    nights = choice!(agency, actor, departure, offering, name: "Extension nights", role: "add_on", scope: "per_unit", pattern: "optional_multiple")
    (1..4).each do |day|
      ROOM_PRICES.each { |type, amount| room_option!(agency, actor, departure, offering, nights, type, hotel_groups.fetch("Nov #{day} #{type}"), amount, label: "Nov #{day} #{type}") }
    end

    tour = choice!(agency, actor, departure, offering, name: "Private Miami tour", role: "add_on", scope: "per_traveler", pattern: "optional_single")
    tour_option = option!(agency, actor, departure, offering, tour, label: "Private Miami tour, Nov 5", inventory_group_id: arrangements.fetch(:excursion).inventory_groups.sole.id)
    price!(agency, actor, departure, offering, tour_option, "any", 150)
    price!(agency, actor, departure, offering, tour_option, "any", 0, traveler_type_id: agency.traveler_types.find_by!(name: "Child 0–4").id)
    offering.reload
  end
  private_class_method :package!

  def self.room_option!(agency, actor, departure, offering, choice, type, group, amount, label: type)
    option = option!(agency, actor, departure, offering, choice, label:, inventory_group_id: group.id)
    price!(agency, actor, departure, offering, option, "guest_1", amount)
    price!(agency, actor, departure, offering, option, "any", 0)
  end
  private_class_method :room_option!

  def self.choice!(agency, actor, departure, offering, **attributes)
    created!(SaveOfferingChoice.new(agency:, actor:, departure:, offering:, attributes:).call, attributes.fetch(:name))
  end
  private_class_method :choice!

  def self.option!(agency, actor, departure, offering, choice, **attributes)
    created!(SaveOfferingOption.new(agency:, actor:, departure:, offering:, choice:, attributes:).call, attributes.fetch(:label))
  end
  private_class_method :option!

  def self.price!(agency, actor, departure, offering, option, position, amount, traveler_type_id: nil)
    created!(SaveOfferingPrice.new(agency:, actor:, departure:, offering:, option:,
      attributes: { occupancy_position: position, amount: amount.to_s, traveler_type_id: }).call, "#{option.label} #{position}")
  end
  private_class_method :price!

  # D-93: the D-93 tiers as this departure's override; the $500 deposit per
  # cruise cabin at confirmation, not counting as acceptance (B7, BKG-41);
  # the balance 120 days before departure.
  def self.client_terms!(agency, actor, departure)
    existing = departure.reload.current_client_terms
    return existing if existing

    version = created!(StartClientTerms.new(agency:, actor:, departure:).call, "client terms")
    UpdateClientTerms.new(agency:, actor:, departure:, terms_version: version, lock_version: version.lock_version, attributes: {
      departure_wording: "Alpha Omega sails Nov 6–13, 2027. The Nov 5 hotel night is included.", overrides_cancellation_tiers: true
    }).call
    version.reload.own_cancellation_tiers.each { |tier| RemoveCancellationTier.new(agency:, actor:, departure:, terms_version: version, tier:).call }
    CANCELLATION_TIERS.each do |days, percentage|
      SaveCancellationTier.new(agency:, actor:, departure:, terms_version: version,
        attributes: { min_days_before_departure: days, charge_kind: "percentage", percentage: }).call
    end
    [ { description: "Deposit", basis: "per_unit", service_category: "cruise", amount: "500", due_rule: "at_confirmation" },
      { description: "Balance", basis: "balance", due_rule: "days_before_departure", days_before_departure: "120" } ].each do |attributes|
      SaveClientScheduleLine.new(agency:, actor:, departure:, terms_version: version, attributes:).call
    end
    version.reload
  end
  private_class_method :client_terms!

  # Agreement A's deposits (B2, B3), the hotel's firm rooms paid at checkout
  # (B4, B14) and the first excursion resource paid with the final count (B8,
  # B13). Confirmation records no cost (D-75); these are staff entries.
  def self.money!(agency, actor, departure, arrangement, key)
    deadline = ->(description) { arrangement.deadlines.find_by!(description:).id }
    case key
    when :cruise
      schedule!(agency, actor, departure, arrangement, description: "Initial deposit, $50 per stateroom", amount_kind: "per_unit_count", rate: "50",
        due_rule: "fixed_date", due_on: Date.new(2026, 11, 1), supplier_deadline_id: deadline.("Initial deposit, $50 per stateroom"))
      schedule!(agency, actor, departure, arrangement, description: "Full deposit, $450 per cabin", amount_kind: "per_shell", rate: "450",
        due_rule: "earlier_of", trigger_type: "client_booking_confirmed", due_on: Date.new(2027, 3, 1),
        supplier_deadline_id: deadline.("Full deposit and names for cabins not yet named"))
    when :hotel
      arrangement.inventory_groups.where(label: HOTEL_FIRM_ROOMS.keys).each do |group|
        rate = HOTEL_FIRM_ROOMS.fetch(group.label)
        attributes = group.represented_as_unit_shells? ? { scope: "unit_shells", unit_shell_ids: group.unit_shells.map(&:id) } : { scope: "inventory_group", inventory_group_id: group.id, quantity: group.quantity }
        cost = created!(SaveCostLine.new(agency:, actor:, departure:, arrangement:, attributes: {
          description: "#{group.label}, firm rooms", basis: "per_unit", rate:, stage: "committed", **attributes
        }).call, group.label)
        schedule!(agency, actor, departure, arrangement, description: "#{group.label}, paid at checkout", cost_line_id: cost.id,
          amount_kind: "percentage_of_cost_line", percentage: "100", due_rule: "fixed_date", due_on: Date.new(2027, 11, 6),
          supplier_deadline_id: deadline.("Payment in full at checkout"))
      end
    when :excursion
      shell = arrangement.inventory_groups.sole.unit_shells.first
      cost = created!(SaveCostLine.new(agency:, actor:, departure:, arrangement:, attributes: {
        description: "First resource, 10 positions", scope: "unit_shells", unit_shell_ids: [ shell.id ], basis: "fixed", rate: "1000", stage: "committed"
      }).call, "First resource")
      schedule!(agency, actor, departure, arrangement, description: "First resource, due with the final count", cost_line_id: cost.id,
        amount_kind: "percentage_of_cost_line", percentage: "100", due_rule: "earlier_of", trigger_type: "final_count_submitted",
        due_on: Date.new(2027, 10, 22), supplier_deadline_id: deadline.("Payment, $1,000 per confirmed resource"))
    end
  end
  private_class_method :money!

  def self.schedule!(agency, actor, departure, arrangement, **attributes)
    created!(SaveScheduleLine.new(agency:, actor:, departure:, arrangement:, attributes:).call, attributes.fetch(:description))
  end
  private_class_method :schedule!

  def self.deadlines!(agency, actor, departure, arrangement, deadlines)
    deadlines.each do |attributes|
      created!(SaveSupplierDeadline.new(agency:, actor:, departure:, arrangement:, attributes:).call, attributes.fetch(:description))
    end
  end
  private_class_method :deadlines!

  def self.group!(agency, actor, departure, arrangement, **attributes)
    created!(SaveInventoryGroup.new(agency:, actor:, departure:, arrangement:, attributes:).call, attributes.fetch(:label))
  end
  private_class_method :group!

  def self.supplier!(agency, actor, definition)
    existing = agency.suppliers.find_by(kind: "organization", display_name: definition.fetch(:display_name))
    return existing if existing

    result = CreateSupplier.new(
      agency:,
      actor:,
      kind: "organization",
      names: { display_name: definition.fetch(:display_name) },
      categories: definition.fetch(:categories)
    ).call
    created!(result, definition.fetch(:display_name))
  end
  private_class_method :supplier!

  def self.departure!(agency, actor)
    departure = agency.departures.find_by(name: DEPARTURE_NAME) || create_departure!(agency, actor)
    if departure.decision_undecided?
      RecordDepartureDecision.new(agency:, actor:, departure:, decision: "proceed", lock_version: departure.lock_version).call
      departure.reload
    end
    if departure.draft?
      MarkDepartureReadyToSell.new(agency:, actor:, departure:, lock_version: departure.lock_version).call
      departure.reload
    end
    departure
  end
  private_class_method :departure!

  def self.create_departure!(agency, actor)
    result = CreateDeparture.new(
      agency:,
      actor:,
      attributes: {
        name: DEPARTURE_NAME,
        description: DEPARTURE_DESCRIPTION,
        starts_on: STARTS_ON,
        ends_on: ENDS_ON,
        time_zone: TIME_ZONE,
        operating_currency: CURRENCY
      }
    ).call
    created!(result, DEPARTURE_NAME)
  end
  private_class_method :create_departure!

  # D-94: the Slice 1 roster's placeholder travelers. The responsible client
  # comes first and travels, linked as Self; the others are family members.
  # Dates of birth give the roster's ages at sailing.
  ROSTER = {
    "BK-101" => [
      { given_names: "Nadia", surname: "Rowan", date_of_birth: Date.new(1979, 12, 2) },
      { given_names: "Theo", surname: "Rowan", date_of_birth: Date.new(1978, 8, 15) },
      { given_names: "Iris", surname: "Rowan", date_of_birth: Date.new(2018, 7, 22) }
    ],
    "BK-104" => [
      { given_names: "Sofia", surname: "Bennett", date_of_birth: Date.new(1985, 9, 3) },
      { given_names: "Marcus", surname: "Bennett", date_of_birth: Date.new(1983, 1, 27) },
      { given_names: "Ava", surname: "Bennett", date_of_birth: Date.new(2016, 2, 8) },
      { given_names: "Milo", surname: "Bennett", date_of_birth: Date.new(2025, 3, 14) }
    ],
    "BK-105" => [
      { given_names: "Mateo", surname: "Rivera", date_of_birth: Date.new(1990, 5, 11) },
      { given_names: "Elena", surname: "Rivera", date_of_birth: Date.new(1991, 10, 30) },
      { given_names: "Luca", surname: "Rivera", date_of_birth: Date.new(2024, 6, 20) }
    ]
  }.freeze

  # One responsible client, its travelers and a Client Trip on the Departure
  # per roster booking, keyed by the roster's booking label.
  def self.roster!(agency, actor, departure)
    ROSTER.to_h do |label, travelers|
      lead, *others = travelers
      client = roster_client!(agency, actor, lead)
      others.each do |details|
        next if client.travelers.exists?(given_names: details[:given_names], surname: details[:surname])

        created!(SaveTraveler.new(agency:, actor:, attributes: details, link_client: client, relationship: "family_member").call, details[:given_names])
      end
      trip = client.client_trips.find_by(departure:) ||
        created!(SaveClientTrip.new(agency:, actor:, attributes: { client_id: client.id, departure_id: departure.id }).call, "the #{label} trip")
      [ label, trip ]
    end
  end

  def self.roster_client!(agency, actor, lead)
    person = agency.client_people.find_by(first_name: lead[:given_names], last_name: lead[:surname])
    client = person&.client ||
      created!(CreateIndividualClient.new(agency:, actor:, names: { first_name: lead[:given_names], last_name: lead[:surname] }, also_traveling: true).call,
        "#{lead[:given_names]} #{lead[:surname]}")
    self_traveler = client.travelers.find_by(given_names: lead[:given_names], surname: lead[:surname])
    if self_traveler && self_traveler.date_of_birth.nil?
      SaveTraveler.new(agency:, actor:, traveler: self_traveler, attributes: { date_of_birth: lead[:date_of_birth] }, lock_version: self_traveler.lock_version).call
    end
    client
  end
  private_class_method :roster!, :roster_client!

  # D-94 and D-95: each Slice 1 roster booking's cabin, hotel rooms (each a
  # list of given names, guest order), extension nights and tour
  # participants. Children 0–4 share a room without using a place.
  ROSTER_BOOKINGS = {
    "BK-101" => { cabin: "V01", room: "Garden Queen", rooms: [ %w[Nadia Iris], %w[Theo] ], nights: [ 4 ], tour: %w[Nadia Theo Iris] },
    "BK-104" => { cabin: "S01", room: "Harbor Double", rooms: [ %w[Sofia Marcus Ava Milo] ], nights: [ 2, 3, 4 ], tour: %w[Sofia Marcus Ava Milo] },
    "BK-105" => { cabin: "O01", room: "Garden Queen", rooms: [ %w[Mateo Elena Luca] ], nights: [], tour: %w[Mateo Luca] }
  }.freeze

  # D-94: each Slice 1 booking's acceptance, recorded and confirmed on its date.
  ROSTER_CONFIRMATIONS = {
    "BK-101" => { on: Time.utc(2027, 1, 12, 15), method: "email", evidence_reference: "Nadia Rowan's email of Jan 12, 2027, in the bookings mailbox" },
    "BK-104" => { on: Time.utc(2027, 1, 19, 15), method: "phone", note: "Sofia Bennett accepted the price and terms by phone." },
    "BK-105" => { on: Time.utc(2027, 2, 2, 15), method: "in_person", note: "Mateo Rivera accepted the price and terms in person." }
  }.freeze

  # D-96 (3): D9's payments, each recorded on its date and applied to the
  # booking's deposit. BK-105's goes straight to Alpha Cruises.
  ROSTER_PAYMENTS = {
    "BK-101" => { on: Time.utc(2027, 1, 12, 16), route: "agency", payment_method: "check", reference: "Check 1047" },
    "BK-104" => { on: Time.utc(2027, 1, 19, 16), route: "agency", payment_method: "bank_transfer", reference: "Transfer 0119" },
    "BK-105" => { on: Time.utc(2027, 2, 2, 16), route: "supplier", payment_method: "card", supplier_reference: "8812457" }
  }.freeze
  ROSTER_PAYMENT_AMOUNT = "500"

  def self.roster_payments!(agency, actor, bookings, arrangements)
    ROSTER_PAYMENTS.each do |label, plan|
      booking = bookings.fetch(label)
      trip = booking.client_trip
      next if trip.client_payments.exists?

      Clock.use(Clock.fixed(plan.fetch(:on))) do
        deposit = booking.client_charge.installments.first
        created!(RecordClientPayment.new(agency:, actor:, trip:, applications: [ { installment_id: deposit.id, amount: ROSTER_PAYMENT_AMOUNT } ], attributes: {
          payer_client_id: trip.client_id, paid_on: plan.fetch(:on).to_date.iso8601, amount: ROSTER_PAYMENT_AMOUNT, route: plan.fetch(:route),
          supplier_id: (arrangements.fetch(:cruise).supplier_id if plan.fetch(:route) == "supplier"), payment_method: plan.fetch(:payment_method),
          reference: plan[:reference], supplier_reference: plan[:supplier_reference]
        }).call, "the #{label} payment")
      end
    end
  end
  private_class_method :roster_payments!

  # A booking on each roster trip, with its travelers, choices and a hold
  # placed at the current clock; with confirm:, each is held, accepted and
  # confirmed at its roster date instead. Reused when the trip already has one.
  def self.roster_bookings!(agency, actor, trips, confirm: false)
    trips.to_h do |label, trip|
      booking = trip.client_bookings.where.not(status: "discarded").first
      if confirm
        Clock.use(Clock.fixed(ROSTER_CONFIRMATIONS.fetch(label).fetch(:on))) do
          booking ||= roster_booking!(agency, actor, trip, ROSTER_BOOKINGS.fetch(label))
          confirm_roster_booking!(agency, actor, booking.reload, ROSTER_CONFIRMATIONS.fetch(label)) if booking.status_draft?
        end
      else
        booking ||= roster_booking!(agency, actor, trip, ROSTER_BOOKINGS.fetch(label))
      end
      [ label, booking.reload ]
    end
  end

  def self.confirm_roster_booking!(agency, actor, booking, plan)
    HoldBookingSpace.new(agency:, actor:, booking:).call if booking.hold_state.first != :held
    RecordBookingAcceptance.new(agency:, actor:, booking: booking.reload, attributes: {
      accepted_by: booking.client_trip.client.source.display_name, acceptance_method: plan.fetch(:method),
      note: plan[:note], evidence_reference: plan[:evidence_reference]
    }).call
    ConfirmClientBooking.new(agency:, actor:, booking: booking.reload).call
  end

  def self.roster_booking!(agency, actor, trip, plan)
    booking = created!(CreateClientBooking.new(agency:, actor:, trip:).call, "the #{trip.trip_reference} booking")
    sailing = STARTS_ON
    types = agency.traveler_types.index_by(&:name)
    travelers = trip.client.traveler_links.includes(:traveler).sort_by { |link| [ link.related_as_self? ? 0 : 1, -link.traveler.age_on(sailing).to_i ] }.to_h do |link|
      age = link.traveler.age_on(sailing)
      type = age < 5 ? types.fetch("Child 0–4") : (age < 18 ? types.fetch("Child") : types.fetch("Adult"))
      row = created!(SaveBookingTraveler.new(agency:, actor:, booking:, attributes: { traveler_id: link.traveler.id, traveler_type_id: type.id }).call, link.traveler.given_names)
      [ link.traveler.given_names, row ]
    end
    choices = booking.offering.choices.includes(:options).index_by(&:name)
    select = lambda do |choice, label, names|
      option = choices.fetch(choice).options.find { |candidate| candidate.label == label }
      SaveChoiceSelection.new(agency:, actor:, booking:, attributes: { offering_option_id: option.id, occupant_ids: names.map { |name| travelers.fetch(name).id } }).call
    end
    order = travelers.keys
    select.call("Cabin", plan[:cabin], order)
    plan[:rooms].each do |names|
      select.call("Nov 5 hotel room", plan[:room], names.sort_by { |name| order.index(name) })
      plan[:nights].each { |day| select.call("Extension nights", "Nov #{day} #{plan[:room]}", names.sort_by { |name| order.index(name) }) }
    end
    select.call("Private Miami tour", "Private Miami tour, Nov 5", plan[:tour])
    HoldBookingSpace.new(agency:, actor:, booking:).call
    booking
  end
  private_class_method :roster_bookings!, :roster_booking!, :confirm_roster_booking!

  def self.created!(result, name)
    return result.record if result.status == :created && result.record

    raise "The Alpha fixture could not create #{name} (#{result.status})."
  end
  private_class_method :created!
end
