# Records or changes a schedule line (SMN-04, SMN-10, SMN-11). It pays
# toward its cost line or the arrangement, and never adds to cost
# (SMN-03). Naming the supplier deadline it pays reuses that deadline's
# task; otherwise a dated line gets its own payment task now, and an
# event-only line gets one when it first posts (SMN-17). A line is fixed
# once an amount posts against it. A line already due posts at once.
class SaveScheduleLine < AgencyCommand
  include ArrangementCommandSupport
  include SupplierMoneyCommandSupport
  include SupplierAmountPosting

  FIELDS = %w[
    description cost_line_id supplier_deadline_id inventory_group_id amount_kind amount rate percentage
    due_rule due_on trigger_type days_after
  ].freeze
  OWN_TASK_WAIVED = "The schedule line now pays a supplier deadline, whose task follows it."

  def initialize(agency:, actor:, departure:, arrangement:, attributes:, schedule_line: nil, lock_version: nil)
    @agency = agency
    @actor = actor
    @departure = departure
    @arrangement = arrangement
    @schedule_line = schedule_line
    @attributes = attributes.to_h.stringify_keys.slice(*FIELDS).transform_values { |value| value.is_a?(String) ? value.strip.presence : value }
    @lock_version = lock_version
  end

  def call
    ensure_departure_actor!(:manage_arrangements)

    ActiveRecord::Base.transaction do
      departure = lock_arrangement_context!
      arrangement = lock_arrangement!(departure)
      ensure_open_arrangement!(arrangement)

      line = @schedule_line ? locked_line(arrangement) : arrangement.schedule_lines.new(agency: @agency, currency: arrangement.currency)
      creating = line.new_record?
      raise Error.new("An amount has posted from this schedule line, so it can't change.", code: :invalid_state) if !creating && line.amounts_due.exists?

      assign!(arrangement, line)
      changed = line.changed - %w[lock_version updated_at]
      return Result.new(status: :noop, record: line) if !creating && changed.empty?

      line.save!
      audit!(
        agency: @agency, action: creating ? "supplier_arrangement.schedule_line_added" : "supplier_arrangement.schedule_line_updated",
        subject: arrangement, actor: @actor,
        details: { "schedule_line_id" => line.id, "amount_kind" => line.amount_kind, "due_rule" => line.due_rule,
                   "due_on" => line.due_on&.iso8601, "trigger_type" => line.trigger_type, "changed" => changed.sort }.compact
      )
      sync_task!(departure, arrangement, line)
      post_amounts_due!(departure, arrangement)
      Result.new(status: creating ? :created : :updated, record: line)
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  end

  private

  def locked_line(arrangement)
    arrangement.schedule_lines.lock.find(@schedule_line.id).tap do |line|
      raise Error.new(STALE_MESSAGE, code: :conflict) if @lock_version.blank? || line.lock_version != @lock_version.to_i
    end
  end

  def assign!(arrangement, line)
    currency = arrangement.currency
    kind = @attributes["amount_kind"] || line.amount_kind
    raise Error.new("Choose how the amount is worked out.", code: :invalid) unless ScheduleLine::AMOUNT_KINDS.include?(kind)

    rule = @attributes["due_rule"] || line.due_rule
    raise Error.new("Choose when it falls due.", code: :invalid) unless ScheduleLine::DUE_RULES.include?(rule)

    cost_line = find_in!(arrangement.cost_lines, "cost_line_id", "Cost line")
    raise Error.new("Choose the cost line the percentage applies to.", code: :invalid) if kind == "percentage_of_cost_line" && cost_line.nil?

    line.assign_attributes(
      description: @attributes.fetch("description", line.description), amount_kind: kind, due_rule: rule, cost_line:,
      supplier_deadline: find_in!(arrangement.deadlines, "supplier_deadline_id", "Supplier deadline"),
      inventory_group: find_in!(arrangement.inventory_groups, "inventory_group_id", "Inventory group"),
      amount_minor_units: kind == "fixed" ? parse_money!("amount", "Amount", currency, required: true) : nil,
      rate_minor_units: kind.in?(%w[per_unit_count per_shell]) ? parse_money!("rate", "Amount per unit", currency, required: true) : nil,
      percentage: kind == "percentage_of_cost_line" ? parse_percentage!("percentage") : nil,
      due_on: rule.in?(%w[fixed_date earlier_of]) ? required_date : nil,
      trigger_type: rule == "fixed_date" ? nil : required_trigger,
      days_after: rule == "event_plus_days" ? parse_count!("days_after", "Days after the event") : nil
    )
  end

  def required_date
    parse_date(@attributes["due_on"], "Due date") or raise Error.new("Due date is required.", code: :invalid)
  end

  def required_trigger
    type = @attributes["trigger_type"]
    raise Error.new("Choose the event it falls due on.", code: :invalid) unless TriggerEvent::TYPES.include?(type)
    raise Error.new("Names submitted isn't a posting event in this slice (D-81).", code: :invalid) if type == "names_submitted"

    type
  end

  def sync_task!(departure, arrangement, line)
    task = Task.lock.find_by(schedule_line_id: line.id)
    if line.supplier_deadline_id
      waive_task!(task, OWN_TASK_WAIVED) if task&.active?
    elsif line.dated?
      if task.nil?
        create_payment_task!(departure, action: "#{arrangement.supplier.display_name}: #{line.description}", due_on: line.due_on,
          source: "schedule_line", schedule_line: line)
      elsif task.due_on != line.due_on
        task.update!(due_on: line.due_on, due_at: AgencyLocalTime.end_of_date(line.due_on, @agency.default_timezone))
        audit_task!(task, "departure.task_due_changed", "due_at" => task.due_at.iso8601)
      end
    end
  end
end
