# Records or changes a supplier deadline on a Draft or Confirmed
# arrangement (SUP-22 to SUP-24). The resolved instant is stored when the
# deadline is recorded or changed (SET-10). An actionable deadline gets
# its task in the same transaction (SUP-23); a change updates that task's
# due date and keeps its history, and never reopens a completed task
# unless the deadline becomes actionable again (OPS-04).
class SaveSupplierDeadline < AgencyCommand
  include ArrangementCommandSupport
  include TaskCommandSupport

  FIELDS = %w[deadline_type actionable description due_on due_at_time time_zone inventory_group_id].freeze
  TIME_FORMAT = /\A([01]\d|2[0-3]):([0-5]\d)(?::00)?\z/

  def initialize(agency:, actor:, departure:, arrangement:, attributes:, deadline: nil, lock_version: nil)
    @agency = agency
    @actor = actor
    @departure = departure
    @arrangement = arrangement
    @deadline = deadline
    @attributes = attributes.to_h.stringify_keys.slice(*FIELDS).transform_values { |value| value.is_a?(String) ? value.strip.presence : value }
    @lock_version = lock_version
  end

  def call
    ensure_departure_actor!(:manage_arrangements)

    ActiveRecord::Base.transaction do
      departure = lock_arrangement_context!
      arrangement = lock_arrangement!(departure)
      raise Error.new("Deadlines can be recorded only on a draft or confirmed arrangement.", code: :invalid_state) unless arrangement.draft? || arrangement.confirmed?

      deadline = @deadline ? locked_deadline(arrangement) : arrangement.deadlines.new(agency: @agency)
      creating = deadline.new_record?
      was_actionable = deadline.actionable
      previous_resolved_at = deadline.resolved_at
      deadline.assign_attributes(deadline_attributes(arrangement, departure, deadline))
      changed = deadline.changed - %w[lock_version updated_at]
      return Result.new(status: :noop, record: deadline) if !creating && changed.empty?

      deadline.save!
      audit!(
        agency: @agency, action: creating ? "supplier_arrangement.deadline_recorded" : "supplier_arrangement.deadline_updated",
        subject: arrangement, actor: @actor,
        details: { "supplier_deadline_id" => deadline.id, "deadline_type" => deadline.deadline_type, "actionable" => deadline.actionable,
                   "resolved_at" => deadline.resolved_at.iso8601, "previous_resolved_at" => previous_resolved_at&.iso8601,
                   "changed" => changed.sort }.compact
      )
      sync_task!(departure, arrangement, deadline, became_actionable: deadline.actionable && !creating && !was_actionable)
      Result.new(status: creating ? :created : :updated, record: deadline)
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  end

  private

  def locked_deadline(arrangement)
    arrangement.deadlines.lock.find(@deadline.id).tap do |deadline|
      raise Error.new(STALE_MESSAGE, code: :conflict) if @lock_version.blank? || deadline.lock_version != @lock_version.to_i
    end
  end

  def deadline_attributes(arrangement, departure, deadline)
    type = @attributes.fetch("deadline_type", deadline.deadline_type)
    raise Error.new("Choose a deadline type.", code: :invalid) unless SupplierDeadline::TYPES.include?(type)

    actionable = if @attributes.key?("actionable") && !@attributes["actionable"].nil?
      ActiveModel::Type::Boolean.new.cast(@attributes["actionable"])
    elsif deadline.new_record?
      SupplierDeadline.default_actionable?(type)
    else
      deadline.actionable
    end
    due_on = @attributes.key?("due_on") ? parse_date(@attributes["due_on"], "Due date") : deadline.due_on
    raise Error.new("Enter the due date.", code: :invalid) if due_on.nil?

    due_at_time = @attributes.key?("due_at_time") ? parse_time(@attributes["due_at_time"]) : deadline.due_at_time
    time_zone = deadline_time_zone(departure, deadline, due_at_time)
    {
      "deadline_type" => type, "actionable" => actionable,
      "description" => @attributes.fetch("description", deadline.description),
      "due_on" => due_on, "due_at_time" => due_at_time&.strftime("%H:%M"), "time_zone" => time_zone,
      "inventory_group" => deadline_group(arrangement, deadline),
      "resolved_at" => SupplierDeadline.resolve(due_on:, due_at_time:, time_zone:)
    }
  end

  # SUP-24 keeps the supplier's stated zone for a timed deadline; a
  # date-only deadline resolves in the agency's zone (SET-10).
  def deadline_time_zone(departure, deadline, due_at_time)
    return @agency.default_timezone if due_at_time.nil?

    zone = @attributes.key?("time_zone") ? @attributes["time_zone"] : deadline.time_zone
    zone = normalize_time_zone(zone) if zone.present?
    zone.presence || departure.time_zone.presence || @agency.default_timezone
  end

  def deadline_group(arrangement, deadline)
    return deadline.inventory_group unless @attributes.key?("inventory_group_id")
    return nil if @attributes["inventory_group_id"].blank?

    group = arrangement.inventory_groups.find_by(id: parse_optional_uuid(@attributes["inventory_group_id"], "Inventory group"))
    raise Error.new("Choose one of this arrangement's inventory groups.", code: :invalid) if group.nil?

    group
  end

  def parse_time(value)
    return nil if value.blank?
    return value if value.respond_to?(:hour) && value.respond_to?(:min)

    match = TIME_FORMAT.match(value.to_s) or raise Error.new("Enter the time as hours and minutes, such as 17:00.", code: :invalid)
    Time.utc(2000, 1, 1, match[1].to_i, match[2].to_i)
  end

  def sync_task!(departure, arrangement, deadline, became_actionable:)
    task = Task.lock.find_by(supplier_deadline_id: deadline.id)
    if deadline.actionable?
      return create_deadline_task!(departure, arrangement, deadline) if task.nil?

      task.assign_attributes(deadline_task_attributes(arrangement, deadline))
      if task.changed?
        changes = task.changed
        task.save!
        audit_task!(task, "departure.task_due_changed", "due_at" => task.due_at.iso8601, "changed" => changes.sort)
      end
      reopen_task!(task) if became_actionable && !task.active?
    elsif task&.active?
      waive_task!(task, INFORMATIONAL_REASON)
    end
  end
end
