# Confirms a draft booking (BKG-45, BKG-25; step 6 plan, questions 2, 10
# and 11). It needs the client's acceptance of the current price and
# terms, every required choice, every traveler named with a date of birth,
# and a hold matching the booking with no capacity conflict; a refusal
# lists what is missing, each linked to where it is fixed (D16). Payment
# is never required (BKG-46).
#
# In one transaction, under the booking lock order:
# 1. Held allocations become Reserved, and each traveler's name as booked
#    is snapshotted (CLT-13).
# 2. The client charge and its lines are made from the price lines, with
#    the accepted terms (BKG-25, CMN-01 to CMN-03, D-94).
# 3. For each unit drawn from a rate table, a committed cost line scoped
#    to the booking is proposed at the actual occupancy, unless its shells
#    are already covered by a commitment for unsold space, and an expected
#    commission is recorded either way (SUP-35, SMN-02, SMN-32, D-75).
# 4. One Client booking confirmed event per arrangement names the shells
#    the booking holds, and what it makes due posts (SMN-11, D-81).
class ConfirmClientBooking < AgencyCommand
  include BookingCommandSupport
  include SupplierAmountPosting

  class Blocked < AgencyCommand::Error
    attr_reader :blockers

    def initialize(blockers)
      @blockers = blockers
      super("This booking can't be confirmed yet.", code: :invalid_state)
    end
  end

  def initialize(agency:, actor:, booking:)
    @agency = agency
    @actor = actor
    @booking = booking
  end

  def call
    ensure_actor!

    ActiveRecord::Base.transaction do
      booking = lock_booking!
      ensure_draft!(booking)
      lock_groups!(booking.inventory_allocations.reject(&:state_released?).map(&:inventory_group))
      blockers = BookingConfirmationCheck.new(booking).blockers
      raise Blocked.new(blockers) if blockers.any?

      now = Clock.current.now
      acceptance = booking.current_acceptance
      reserved = reserve!(booking, now)
      booking.booking_travelers.each { |row| row.update!(name_as_booked: row.traveler.legal_name) }
      charge = create_charge!(booking, acceptance, now)
      costs, commissions = propose_supplier_cost!(booking, reserved)
      events = record_confirmed_events!(booking, reserved)
      booking.update!(status: "confirmed", confirmed_at: now)
      audit_booking!(booking, "client_booking.confirmed",
        "client_charge_id" => charge.id, "charge_total_minor_units" => charge.total_minor_units, "booking_acceptance_id" => acceptance.id,
        "reserved_allocation_ids" => reserved.map(&:id), "cost_line_ids" => costs.map(&:id),
        "expected_commission_ids" => commissions.map(&:id), "trigger_event_ids" => events.map(&:id))
      Result.new(status: :updated, record: booking)
    end
  rescue ActiveRecord::RecordInvalid => error
    raise Error.new(error.record.errors.full_messages.to_sentence, code: :invalid)
  end

  private

  def reserve!(booking, now)
    booking.inventory_allocations.select(&:lapsed?).each { |allocation| allocation.update!(state: "released", released_at: now) }
    booking.consuming_allocations.select(&:state_held?).each { |allocation| allocation.update!(state: "reserved", reserved_at: now) }
    booking.inventory_allocations.select(&:state_reserved?)
  end

  def create_charge!(booking, acceptance, now)
    charge = booking.create_client_charge!(agency: @agency, client_terms_version: booking.client_terms_version, booking_acceptance: acceptance,
      currency: booking.currency, created_at: now)
    booking.price_lines.includes(choice_selection: { option: :choice }).each do |line|
      selection = line.choice_selection
      charge.lines.create!(
        agency: @agency, line_type: selection.option.choice.included? ? "traveler_price" : "add_on", choice_selection: selection,
        booking_traveler_id: line.booking_traveler_id, traveler_type_id: line.traveler_type_id, occupancy_position: line.occupancy_position,
        description: selection.label, amount_minor_units: line.amount_minor_units, currency: line.currency, created_at: now
      )
    end
    charge
  end

  # SUP-35, D-75: cost and commission from the rate table at the actual occupancy.
  def propose_supplier_cost!(booking, reserved)
    costs = []
    commissions = []
    booking.choice_selections.select(&:per_unit?).each do |selection|
      group = selection.inventory_group
      next if group.rate_lines.empty?

      proposal = supplier_proposal(booking, selection)
      arrangement = group.supplier_arrangement
      shells = reserved.select { |allocation| allocation.choice_selection_id == selection.id }.filter_map(&:unit_shell)
      unless covered_by_unsold_space?(shells)
        line = arrangement.cost_lines.create!(
          agency: @agency, scope: "client_booking", client_booking: booking, description: "#{booking.booking_reference} · #{selection.label}",
          basis: "fixed", rate_minor_units: proposal.gross, amount_minor_units: proposal.gross, currency: proposal.currency, stage: "committed"
        )
        shells.each { |shell| line.cost_line_shells.create!(agency: @agency, unit_shell: shell) }
        costs << line
      end
      commissions << booking.expected_commissions.create!(
        agency: @agency, supplier_arrangement: arrangement, choice_selection: selection,
        proposed_amount_minor_units: proposal.commission, amount_minor_units: proposal.commission, currency: proposal.currency
      )
    end
    [ costs, commissions ]
  end

  def covered_by_unsold_space?(shells)
    shells.any? && CostLineShell.joins(:cost_line).where(unit_shell_id: shells.map(&:id), cost_lines: { scope: "unit_shells", stage: "committed" }).exists?
  end

  # D-81: one event per arrangement, naming the shells the booking holds there.
  def record_confirmed_events!(booking, reserved)
    today = Clock.current.today_in(@agency.default_timezone)
    reserved.group_by { |allocation| allocation.inventory_group.supplier_arrangement }.map do |arrangement, allocations|
      event = arrangement.trigger_events.create!(
        agency: @agency, event_type: "client_booking_confirmed", occurred_on: today, client_booking: booking,
        reference: booking.booking_reference, recorded_by: @actor, recorded_at: Clock.current.now
      )
      allocations.filter_map(&:unit_shell).uniq.each { |shell| event.event_shells.create!(agency: @agency, unit_shell: shell, created_at: Clock.current.now) }
      event.event_shells.reset
      post_amounts_due!(@departure, arrangement.reload)
      event
    end
  end
end
