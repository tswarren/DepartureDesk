# A Departure at a glance (S-06, S-07; UX consolidation audit A3): its
# bookings, the space left in what its package includes, client money,
# supplier money and the next tasks. Read from the records each tab shows,
# never stored. Client and supplier money stay apart and are never netted
# (CMN-06, SMN-26).
#
# Load several at once with DepartureSummary.for(departures), which
# preloads what every summary reads so a list costs the same queries for
# five Departures as for fifty.
class DepartureSummary
  # Space left in one group, now: free units of `total`, or a note when the
  # group has no count (:on_request, :no_count) or is only planned (:planned).
  Space = Data.define(:left, :total, :note) do
    def counted? = note.nil?
  end
  SpaceRow = Data.define(:choice, :label, :space)

  TASKS_SHOWN = 3

  GROUPS = [ :capacity_projection, { supplier_arrangement: [], unit_shells: %i[capacity_events inventory_allocations], inventory_allocations: [] } ].freeze
  PRELOAD = {
    client_trips: [ { client_bookings: [ :booking_travelers, :supplier_reservations, TripMoney::BOOKINGS ] }, { client_payments: TripMoney::PAYMENTS } ],
    offerings: { choices: { options: { inventory_group: GROUPS } } }
  }.freeze

  def self.for(departures)
    ActiveRecord::Associations::Preloader.new(records: departures, associations: PRELOAD).call
    departures.index_with { |departure| new(departure) }
  end

  attr_reader :departure

  def initialize(departure, at: Clock.current.now)
    @departure = departure
    @at = at
  end

  def currency = departure.operating_currency

  # Bookings ----------------------------------------------------------------

  def bookings = @bookings ||= departure.client_trips.flat_map(&:client_bookings)
  def confirmed_bookings = bookings.select(&:status_confirmed?)
  def draft_bookings = bookings.select(&:status_draft?)
  def confirmed_travelers = confirmed_bookings.sum { |booking| booking.booking_travelers.size }

  # Bookings with space still awaiting a supplier's answer (INV-33 to INV-37).
  def awaiting_supplier = confirmed_bookings.select { |booking| booking.supplier_reservations.any?(&:status_requested?) }

  # Space left in what the package includes -----------------------------------

  # One row per option of each included choice, by choice then option.
  def space_rows
    @space_rows ||= departure.offerings.flat_map(&:choices).select(&:included?).flat_map do |choice|
      choice.options.uniq(&:inventory_group_id).map do |option|
        SpaceRow.new(choice: choice.name, label: option.label, space: space(option.inventory_group, per_traveler: choice.made_per_traveler?))
      end
    end
  end

  # Each included choice's counted space added up, for the Departures list.
  def space_by_choice
    space_rows.group_by(&:choice).filter_map do |choice, rows|
      counted = rows.map(&:space).select(&:counted?)
      next if counted.empty?

      [ choice, Space.new(left: counted.sum(&:left), total: counted.sum(&:total), note: nil) ]
    end
  end

  # INV-04, INV-38: what a group can still take now, as the Inventory tab
  # counts it: shells free of any allocation, or a pool's supply less what
  # is held or reserved. A per-traveler choice counts positions in shells.
  def space(group, per_traveler: false)
    return Space.new(left: nil, total: nil, note: :on_request) if group.availability_promise == "on_request"
    return Space.new(left: nil, total: nil, note: :no_count) unless group.numeric?
    return Space.new(left: nil, total: group.quantity, note: :planned) if group.supplier_arrangement.draft?

    if group.represented_as_unit_shells?
      shells = group.unit_shells.reject(&:returned_to_supplier?)
      if per_traveler
        Space.new(left: shells.sum { |shell| shell.positions_left(at: @at) }, total: shells.sum(&:positions), note: nil)
      else
        Space.new(left: shells.count { |shell| shell.status(at: @at) == "available" }, total: shells.size, note: nil)
      end
    else
      supply = group.capacity_projection&.current_supplier_capacity || 0
      allocated = group.inventory_allocations.select { |allocation| allocation.consuming?(at: @at) }.sum(&:quantity)
      Space.new(left: [ supply - allocated, 0 ].max, total: supply, note: nil)
    end
  end

  # Client money (CMN-06) ---------------------------------------------------------

  def trip_money = @trip_money ||= departure.client_trips.map { |trip| TripMoney.new(trip) }
  def charged? = trip_money.any? { |money| money.bookings.any? }
  def still_due_from_clients = trip_money.sum(&:receivable_minor_units)
  def paid_to_agency = trip_money.sum(&:agency_cash_minor_units)
  def paid_to_suppliers_by_clients = trip_money.sum(&:supplier_route_minor_units)
  def next_client_installment = trip_money.flat_map(&:open_installments).min_by { |installment| [ installment.due_on, installment.position ] }

  # Supplier money (SMN-05, SMN-18) ---------------------------------------------
  # Read for one Departure only; the list doesn't show it.

  def amounts_due = @amounts_due ||= AmountDue.where(supplier_arrangement: departure.supplier_arrangements.live).includes(:payment_applications, supplier_arrangement: :supplier).by_due.to_a
  def owed_to_suppliers = amounts_due.sum(&:open_minor_units)
  def next_amount_due = amounts_due.find { |amount| amount.open_minor_units.positive? }
  def committed_cost = CostLine.where(supplier_arrangement: departure.supplier_arrangements.live, stage: "committed").sum(:amount_minor_units)
  def expected_commission = ExpectedCommission.where(supplier_arrangement: departure.supplier_arrangements.live).sum(:amount_minor_units)

  # Tasks (OPS-01, OPS-02) ----------------------------------------------------------

  def active_tasks = @active_tasks ||= departure.tasks.active.by_due.includes(:owner).to_a
  def overdue_tasks = active_tasks.select { |task| task.overdue?(@at) }
  def next_tasks = active_tasks.first(TASKS_SHOWN)
end
