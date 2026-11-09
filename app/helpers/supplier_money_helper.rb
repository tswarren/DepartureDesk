module SupplierMoneyHelper
  COST_SCOPE_LABELS = { "arrangement" => "Whole arrangement", "inventory_group" => "One inventory group", "unit_shells" => "Named shells" }.freeze
  COST_BASIS_LABELS = {
    "fixed" => "Fixed amount", "per_unit" => "Per unit", "per_person" => "Per person", "per_night" => "Per night", "percentage" => "Percentage of a cost line"
  }.freeze
  STAGE_LABELS = { "estimated" => "Estimated", "committed" => "Committed" }.freeze
  AMOUNT_KIND_LABELS = {
    "fixed" => "Fixed amount", "percentage_of_cost_line" => "Percentage of its cost line",
    "per_unit_count" => "Amount per unit, times the count", "per_shell" => "Amount for each shell"
  }.freeze
  DUE_RULE_LABELS = {
    "fixed_date" => "On a fixed date", "event" => "When an event happens", "event_plus_days" => "Days after an event",
    "earlier_of" => "Earlier of an event and a date"
  }.freeze
  TRIGGER_LABELS = {
    "arrangement_confirmed" => "Arrangement confirmed", "names_submitted" => "Names submitted", "client_booking_confirmed" => "Client booking confirmed",
    "rooming_list_submitted" => "Rooming list submitted", "final_count_submitted" => "Final count or manifest submitted",
    "tickets_issued" => "Tickets issued", "supplier_invoice_received" => "Supplier invoice received", "service_date" => "Service date",
    "other" => "Other"
  }.freeze

  def money(minor_units, currency) = Money.new(minor_units, currency).format

  def cost_line_covers(line)
    case line.scope
    when "arrangement" then "Whole arrangement"
    when "inventory_group" then line.inventory_group.label
    else
      line.unit_shells.group_by(&:inventory_group).map { |group, shells| shells.one? ? shells.first.label : "#{shells.size} shells in #{group.label}" }.to_sentence
    end
  end

  # A cell's column name, shown above its value when the table stacks at
  # narrow widths.
  def stacked_label(text) = tag.span(text, class: "dd-cabin-field-label dd-visually-hidden")

  # "$145.00 × 4 per unit", "12.5% of Seats", or "Fixed".
  def cost_line_basis(line)
    case line.basis
    when "fixed" then "Fixed"
    when "percentage" then "#{trim_decimal(line.percentage)}% of #{line.base_cost_line.description}"
    else "#{money(line.rate_minor_units, line.currency)} × #{line.quantity} #{line.basis.tr("_", " ")}"
    end
  end

  def stage_badge(line)
    status_badge(STAGE_LABELS.fetch(line.stage), modifier: line.stage_committed? ? "info" : "neutral")
  end

  # What a payment is for and when it falls due, in one sentence: "$450 for
  # each cabin, due when a client booking for that cabin is confirmed, or on
  # Mar 1, 2027 for any cabin still unbooked."
  def schedule_line_sentence(line)
    unit = payment_unit_noun(line.supplier_arrangement, line.inventory_group)
    "#{payment_how_much(line, unit)}, #{payment_when(line, unit)}."
  end

  # "cabin", "room" or "unit", from the group's service category, or the
  # arrangement's when the payment covers every group.
  def payment_unit_noun(arrangement, group = nil)
    categories = group ? [ group.service_category ] : arrangement.inventory_groups.select(&:represented_as_unit_shells?).map(&:service_category).uniq
    case categories
    when [ "cruise" ] then "cabin"
    when [ "hotel" ], [ "all_inclusive_resort" ] then "room"
    else "unit"
    end
  end

  # The form's "when" choice for a saved line.
  def payment_due_choice(line)
    case line.due_rule
    when "fixed_date" then "date"
    when "event" then line.trigger_type == "client_booking_confirmed" ? "booked" : "after_event"
    when "earlier_of" then "booked_or_date"
    else "after_event"
    end
  end

  # Events staff choose for "some days after an event"; booking confirmation has its own choices.
  PAYMENT_EVENTS = %w[final_count_submitted rooming_list_submitted tickets_issued supplier_invoice_received arrangement_confirmed service_date other].freeze
  PAYMENT_EVENT_PHRASES = {
    "arrangement_confirmed" => "the supplier confirms the arrangement", "client_booking_confirmed" => "a client booking is confirmed",
    "rooming_list_submitted" => "the rooming list is sent", "final_count_submitted" => "the final count is sent",
    "tickets_issued" => "tickets are issued", "supplier_invoice_received" => "the supplier's invoice arrives",
    "service_date" => "the service date", "other" => "the event is recorded"
  }.freeze

  def amount_due_source(amount)
    amount.direct? ? "Recorded directly" : "Schedule line: #{amount.schedule_line.description}"
  end

  def trim_decimal(value) = value.to_s("F").sub(/\.0\z/, "")

  private

  def payment_how_much(line, unit)
    case line.amount_kind
    when "fixed" then money(line.amount_minor_units, line.currency)
    when "per_shell" then "#{money(line.rate_minor_units, line.currency)} for each #{line.inventory_group ? "#{line.inventory_group.label} " : ""}#{unit}"
    when "per_unit_count" then "#{money(line.rate_minor_units, line.currency)} for each one in the count"
    when "balance" then "The balance of what's committed, less what earlier payments made due"
    else "#{trim_decimal(line.percentage)}% of #{line.cost_line.description}"
    end
  end

  def payment_when(line, unit)
    date = line.due_on&.strftime("%b %-d, %Y")
    per_unit = line.amount_kind == "per_shell"
    booking = line.trigger_type == "client_booking_confirmed"
    event = booking && per_unit ? "a client booking for that #{unit} is confirmed" : PAYMENT_EVENT_PHRASES.fetch(line.trigger_type.to_s, "the event is recorded")
    case line.due_rule
    when "fixed_date" then "due #{date}"
    when "event" then line.trigger_type == "service_date" ? "due on the service date" : "due when #{event}"
    when "event_plus_days" then "due #{pluralize(line.days_after, "day")} after #{event}"
    else booking && per_unit ? "due when #{event}, or on #{date} for any #{unit} still unbooked" : "due when #{event}, or on #{date} at the latest"
    end
  end
end
