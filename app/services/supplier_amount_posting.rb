# Posts amounts due from schedule lines (SMN-05, SMN-06, SMN-10, SMN-13,
# SMN-14, D-81). A line posts when its date arrives or its event is
# recorded:
# - fixed date: on that date;
# - event: on the event's date;
# - a period after an event: that many days after the event's date;
# - the earlier of an event and a date: on whichever comes first, so the
#   date still posts if the event never happens (SMN-13).
# An event's date is when it happened, so a late-recorded event posts at
# once. Amounts are calculated and snapshotted when posted, never
# recalculated. A per-shell line posts once for each shell that isn't
# returned to the supplier and has no amount for it yet; anything else
# posts once. Only a confirmed arrangement posts.
#
# Rounding (ADR 0001): a percentage is applied in exact decimal arithmetic
# and rounded half up to the minor unit, once per amount.
module SupplierAmountPosting
  include TaskCommandSupport

  SYSTEM_ACTOR_IDENTIFIER = "supplier_money.post_amounts_due"

  private

  # The caller holds the arrangement lock. @actor is the posting user, or
  # nil for the system sweep.
  def post_amounts_due!(departure, arrangement)
    return [] unless arrangement.confirmed?

    today = Clock.current.today_in(@agency.default_timezone)
    events = arrangement.trigger_events.to_a
    posted = arrangement.schedule_lines.includes(:cost_line, :amounts_due, :task).flat_map do |line|
      due_on, event = posting_date(line, events)
      next [] if due_on.nil? || due_on > today

      amounts = post_line!(arrangement, line, due_on, event)
      create_line_task!(departure, line, due_on) if amounts.any?
      amounts
    end
    if posted.any?
      audit!(agency: @agency, action: "supplier_arrangement.amounts_due_posted", subject: arrangement,
        actor: @actor, actor_identifier: (@actor ? nil : SYSTEM_ACTOR_IDENTIFIER),
        details: { "amount_due_ids" => posted.map(&:id), "total_minor_units" => posted.sum(&:amount_minor_units),
                   "currency" => arrangement.currency })
    end
    posted
  end

  # [date, event] for a line, or [nil, nil] while it isn't due.
  def posting_date(line, events)
    event = events.select { |candidate| candidate.event_type == line.trigger_type }.min_by(&:occurred_on) if line.trigger_type
    case line.due_rule
    when "fixed_date" then [ line.due_on, nil ]
    when "event" then [ event&.occurred_on, event ]
    when "event_plus_days" then [ event && event.occurred_on + line.days_after, event ]
    when "earlier_of" then event && event.occurred_on <= line.due_on ? [ event.occurred_on, event ] : [ line.due_on, nil ]
    end
  end

  def post_line!(arrangement, line, due_on, event)
    if line.per_shell?
      taken = line.amounts_due.map(&:unit_shell_id)
      eligible_shells(arrangement, line).reject { |shell| taken.include?(shell.id) }.map do |shell|
        create_amount!(arrangement, line, due_on, event, "#{line.description} · #{shell.label}",
          line.rate_minor_units, unit_shell: shell, quantity: 1, rate_minor_units: line.rate_minor_units)
      end
    else
      return [] if line.amounts_due.any?

      [ create_amount!(arrangement, line, due_on, event, line.description, *calculate(arrangement, line, event)) ]
    end
  end

  # [amount, facts] for a line that posts once (SMN-06, SMN-14).
  def calculate(arrangement, line, event)
    case line.amount_kind
    when "fixed"
      [ line.amount_minor_units, {} ]
    when "percentage_of_cost_line"
      base = line.cost_line.amount_minor_units
      amount = (BigDecimal(base) * line.percentage / 100).round(0, BigDecimal::ROUND_HALF_UP).to_i
      [ amount, { percentage: line.percentage, base_minor_units: base } ]
    when "per_unit_count"
      count = event&.count || eligible_shells(arrangement, line).size
      [ line.rate_minor_units * count, { quantity: count, rate_minor_units: line.rate_minor_units } ]
    end
  end

  def eligible_shells(arrangement, line)
    shells = UnitShell.joins(:inventory_group).where(inventory_groups: { supplier_arrangement_id: arrangement.id })
    shells = shells.where(inventory_group_id: line.inventory_group_id) if line.inventory_group_id
    shells.includes(:capacity_events).order("inventory_groups.position", :position).reject(&:returned_to_supplier?)
  end

  def create_amount!(arrangement, line, due_on, event, description, amount, facts)
    arrangement.amounts_due.create!(
      agency: @agency, schedule_line: line, trigger_event: event, description: description.truncate(200),
      amount_minor_units: amount, currency: arrangement.currency, due_on:, posted_at: Clock.current.now,
      posted_by: @actor, posted_by_identifier: (@actor ? nil : SYSTEM_ACTOR_IDENTIFIER), **facts
    )
  end

  # An event-only line without a deadline gets its payment task when it
  # first posts, since a task needs a due instant (SMN-17, OPS-02).
  def create_line_task!(departure, line, due_on)
    return if line.supplier_deadline_id || line.task

    create_payment_task!(departure, action: "#{line.supplier_arrangement.supplier.display_name}: #{line.description}", due_on:,
      source: "schedule_line", schedule_line: line)
  end
end
