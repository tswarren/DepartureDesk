module TasksHelper
  TASK_STATUS_LABELS = { "open" => "Open", "in_progress" => "In progress", "completed" => "Completed", "waived" => "Waived" }.freeze
  TASK_STATUS_MODIFIERS = { "open" => "neutral", "in_progress" => "info", "completed" => "success", "waived" => "neutral" }.freeze
  DEADLINE_TYPE_LABELS = {
    "option_release" => "Option or release", "deposit_payment" => "Deposit or payment", "names_submission" => "Names submission",
    "rooming_list" => "Rooming list", "ticketing" => "Ticketing", "final_count" => "Final count or manifest",
    "cancellation_tier_cutoff" => "Cancellation-tier cutoff", "other" => "Other"
  }.freeze

  def deadline_type_label(value) = DEADLINE_TYPE_LABELS.fetch(value.to_s)

  # Status as text, with Overdue as its own badge: never color alone.
  def task_status_badges(task)
    badges = [ status_badge(TASK_STATUS_LABELS.fetch(task.status), modifier: TASK_STATUS_MODIFIERS.fetch(task.status)) ]
    badges << status_badge("Overdue", modifier: "danger") if task.overdue?
    safe_join(badges, " ")
  end

  # "Mar 1, 2027, 11:59 PM America/New_York": the governing local date,
  # time and zone (SET-10).
  def local_due_label(at, time_zone)
    "#{at.in_time_zone(time_zone).strftime("%b %-d, %Y, %-l:%M %p")} #{time_zone}"
  end

  # The same instant in agency time, when the zone differs.
  def agency_due_label(at, time_zone)
    return if time_zone == Current.agency.default_timezone

    "#{at.in_time_zone(Current.agency.default_timezone).strftime("%b %-d, %Y, %-l:%M %p")} agency time"
  end

  def task_source_label(task)
    return "Manual" unless task.from_supplier_deadline?

    deadline = task.supplier_deadline
    "#{deadline_type_label(deadline.deadline_type)} · #{deadline.supplier_arrangement.supplier.display_name_for_directory}"
  end

  # OPS-04: the task's history, kept in its Departure's audit trail.
  def task_history(task)
    AuditEvent.where(agency_id: task.agency_id, subject_type: "Departure", subject_id: task.departure_id)
      .where("details->>'task_id' = ?", task.id).includes(:actor_agency_user).order(:created_at)
  end

  def task_owner_options
    Current.agency.agency_users.agency_staff.where(status: "active").order(:first_name, :last_name).map { |user| [ user.display_name, user.id ] }
  end
end
