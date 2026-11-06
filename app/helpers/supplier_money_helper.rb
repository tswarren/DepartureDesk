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

  def schedule_line_amount(line)
    case line.amount_kind
    when "fixed" then money(line.amount_minor_units, line.currency)
    when "percentage_of_cost_line" then "#{trim_decimal(line.percentage)}% of #{line.cost_line.description}"
    when "per_unit_count" then "#{money(line.rate_minor_units, line.currency)} per unit, times the count"
    else "#{money(line.rate_minor_units, line.currency)} for each shell"
    end
  end

  def schedule_line_when(line)
    trigger = TRIGGER_LABELS[line.trigger_type]
    date = line.due_on&.to_fs(:long)
    case line.due_rule
    when "fixed_date" then "On #{date}"
    when "event" then "When: #{trigger}"
    when "event_plus_days" then "#{pluralize(line.days_after, "day")} after: #{trigger}"
    else "Earlier of #{trigger} and #{date}"
    end
  end

  def amount_due_source(amount)
    amount.direct? ? "Recorded directly" : "Schedule line: #{amount.schedule_line.description}"
  end

  def trim_decimal(value) = value.to_s("F").sub(/\.0\z/, "")
end
