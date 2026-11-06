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
# each arrangement is confirmed, its supplier cost and schedule (step 4). Each Slice 1
# step extends this script with the records it builds.
# Loading is idempotent: records already present in the agency are reused.
# Pass confirm_cruise: false to stop with the Alpha arrangement in Draft (D1).
module AlphaFixture
  Result = Data.define(:agency, :actor, :suppliers, :departure, :arrangements)

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

  def self.load!(agency:, actor:, confirm_cruise: true)
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
    Result.new(agency:, actor:, suppliers:, departure:, arrangements:)
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

  def self.cruise_inventory!(agency, actor, departure, arrangement)
    CRUISE_CABINS.each do |cabin|
      group = group!(agency, actor, departure, arrangement, label: cabin[:label], service_category: "cruise",
        quantity: 8, positions_per_unit: cabin[:positions], **CRUISE_DATES)
      cruise_rates(cabin).each do |position, (base, nccf, taxes, discount)|
        SaveSupplierRateLine.new(agency:, actor:, departure:, arrangement:, attributes: {
          inventory_group_id: group.id, occupancy_position: position, base_fare: base.to_s, non_commissionable_fees: nccf.to_s,
          taxes: taxes.to_s, discount: discount.to_s, commission_rate: CRUISE_COMMISSION_RATE
        }).call
      end
    end
  end
  private_class_method :cruise_inventory!

  # { "guest_1" => [base fare, NCCF, taxes, discount], ... }
  def self.cruise_rates(cabin)
    first = [ cabin[:base], CRUISE_NCCF, CRUISE_TAXES, cabin[:discount] ]
    additional = [ cabin[:additional_base], CRUISE_NCCF, CRUISE_TAXES, cabin[:additional_discount] ]
    single = [ cabin[:base] * 2, CRUISE_NCCF * 2, CRUISE_TAXES, cabin[:discount] * 2 ]
    { "single" => single, "guest_1" => first, "guest_2" => first }
      .merge((3..cabin[:positions]).to_h { |n| [ "guest_#{n}", additional ] })
  end
  private_class_method :cruise_rates

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
        group!(agency, actor, departure, arrangement, **attributes)
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

  def self.created!(result, name)
    return result.record if result.status == :created && result.record

    raise "The Alpha fixture could not create #{name} (#{result.status})."
  end
  private_class_method :created!
end
