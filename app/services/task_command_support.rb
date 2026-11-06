# Shared steps for task commands (OPS-02 to OPS-04). Lock order: agency,
# Departure, then the task. Each transition is audited against the
# task's Departure.
module TaskCommandSupport
  include DepartureCommandSupport

  DISCARDED_REASON = "arrangement discarded"
  INFORMATIONAL_REASON = "Deadline marked informational."

  private

  # SUP-23: an actionable deadline's task, owned by the Departure's default
  # task owner, else the user who recorded it.
  def create_deadline_task!(departure, arrangement, deadline)
    task = departure.tasks.create!(
      agency: @agency, source: "supplier_deadline", supplier_deadline: deadline, owner: deadline_task_owner(departure),
      **deadline_task_attributes(arrangement, deadline)
    )
    audit_task!(task, "departure.task_created", "owner_id" => task.owner_id, "due_at" => task.due_at.iso8601)
    task
  end

  def deadline_task_attributes(arrangement, deadline)
    {
      action: "#{arrangement.supplier.display_name}: #{deadline.description}".truncate(250),
      due_at: deadline.resolved_at, due_on: deadline.due_on, due_at_time: deadline.due_at_time, due_time_zone: deadline.time_zone
    }
  end

  def deadline_task_owner(departure)
    owner = departure.default_task_owner
    owner&.active? && !owner.reseller? ? owner : @actor
  end

  def waive_task!(task, reason)
    task.update!(status: "waived", waiver_reason: reason, waived_at: Clock.current.now)
    audit_task!(task, "departure.task_waived", "reason" => reason)
  end

  # OPS-04: the same requirement actionable again reopens the existing task
  # with its history.
  def reopen_task!(task)
    task.update!(status: "open", completion_note: nil, completed_at: nil, waiver_reason: nil, waived_at: nil)
    audit_task!(task, "departure.task_reopened")
  end

  def audit_task!(task, action, details = {})
    audit!(agency: @agency, action:, subject: task.departure, actor: @actor,
      details: { "task_id" => task.id, "supplier_deadline_id" => task.supplier_deadline_id }.merge(details))
  end

  def lock_task!(permission)
    lock_authorized_agency!(permission)
    departure_id = @agency.tasks.find(@task.id).departure_id
    departure = @agency.departures.lock.find(departure_id)
    departure.tasks.lock.find(@task.id).tap { |task| ensure_current_task_version!(task) }
  end

  def ensure_task_status!(task, statuses, message)
    raise AgencyCommand::Error.new(message, code: :invalid_state) unless task.status.in?(statuses)
  end

  def ensure_current_task_version!(task)
    raise AgencyCommand::Error.new(STALE_MESSAGE, code: :conflict) if @lock_version.blank? || task.lock_version != @lock_version.to_i
  end

  def normalize_note(value, label)
    note = value.to_s.gsub("\r\n", "\n").strip
    raise AgencyCommand::Error.new("Enter #{label}.", code: :invalid) if note.empty?
    raise AgencyCommand::Error.new("#{label.capitalize} is too long (#{Task::NOTE_LIMIT} characters at most).", code: :invalid) if note.length > Task::NOTE_LIMIT

    note
  end
end
