# Confirms an arrangement in one transaction (SUP-11, SUP-12, ADR 0018): it
# records the supplier's confirmation, then creates each group's unit
# shells or capacity pool with an opening event. Leaving Draft freezes the
# rate table (SUP-35). It records no supplier cost (D-75); booking
# confirmation proposes cost from the rate table.
class ConfirmSupplierArrangement < AgencyCommand
  include CapacityCommandSupport
  include SupplierAmountPosting

  def initialize(agency:, actor:, departure:, arrangement:, confirmed_on:, confirmation_note: nil, lock_version:)
    @agency = agency
    @actor = actor
    @departure = departure
    @arrangement = arrangement
    @confirmed_on = confirmed_on
    @confirmation_note = confirmation_note
    @lock_version = lock_version
  end

  def call
    ensure_departure_actor!(:manage_arrangements)
    confirmed_on = parse_confirmed_on

    ActiveRecord::Base.transaction do
      departure = lock_arrangement_context!
      arrangement = lock_arrangement!(departure)
      ensure_current_lock_version!(arrangement)
      ensure_draft!(arrangement)
      blockers = arrangement.confirmation_blockers
      raise Error.new(blockers.to_sentence, code: :invalid) if blockers.any?

      arrangement.update!(status: "confirmed", confirmed_on:, confirmation_note: @confirmation_note, confirmed_at: Clock.current.now)
      opening_on = [ confirmed_on, Clock.current.today_in(@agency.default_timezone) ].min
      created = arrangement.inventory_groups.lock.to_a.sum { |group| open_inventory!(departure, arrangement, group, opening_on) }
      audit!(
        agency: @agency, action: "supplier_arrangement.confirmed", subject: arrangement, actor: @actor,
        details: { "supplier_arrangement_id" => arrangement.id, "confirmed_on" => confirmed_on.iso8601,
                   "group_reference" => arrangement.group_reference, "shells_created" => created,
                   "rate_lines_frozen" => arrangement.rate_lines.count }
      )
      # SMN-11: Confirm records the Arrangement confirmed event, then posts
      # anything already due.
      arrangement.trigger_events.create!(agency: @agency, event_type: "arrangement_confirmed", occurred_on: confirmed_on,
        recorded_by: @actor, recorded_at: Clock.current.now)
      post_amounts_due!(departure, arrangement)
      Result.new(status: :updated, record: arrangement)
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  end

  private

  def parse_confirmed_on
    raise Error.new("Enter the date the supplier confirmed.", code: :invalid) if @confirmed_on.blank?

    @confirmed_on.is_a?(Date) ? @confirmed_on : Date.iso8601(@confirmed_on.to_s)
  rescue Date::Error
    raise Error.new("Enter the date the supplier confirmed.", code: :invalid)
  end

  # Returns how many shells it created.
  def open_inventory!(departure, arrangement, group, opening_on)
    case group.representation
    when "unit_shells"
      return 0 unless group.numeric?

      create_shells!(group, group.quantity)
      append_capacity_event!(departure:, arrangement:, group:, event_type: "established", quantity: group.quantity, effective_on: opening_on)
      group.quantity
    when "capacity_pool"
      group.create_capacity_pool!(agency: @agency, availability_promise: group.availability_promise)
      append_capacity_event!(departure:, arrangement:, group:, event_type: "established", quantity: group.quantity, effective_on: opening_on) if group.numeric?
      0
    else
      0
    end
  end
end
