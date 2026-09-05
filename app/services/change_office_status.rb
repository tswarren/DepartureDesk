class ChangeOfficeStatus < MembershipCommand
  def initialize(agency:, office:, to:, reason:, actor: nil, actor_identifier: nil, privileged: false)
    @agency = agency
    @office = office
    @to = to.to_s
    @reason = reason.to_s.strip
    assign_command_actors(actor:, actor_identifier:, privileged:)
  end

  def call
    raise Error.new("A reason is required.", code: :invalid) if @reason.blank?

    cleared_office_id = nil

    ActiveRecord::Base.transaction do
      with_agency_office_lock(@agency, office: @office) do
        perform
        cleared_office_id = @office.id if @to == "inactive"
      end
    end

    clear_session_offices_later(cleared_office_id) if cleared_office_id
    CommandResult.new(status: :accepted, office: @office.reload)
  rescue ActiveRecord::StaleObjectError
    raise Error.new("This office was updated by someone else.", code: :conflict)
  end

  private

  def perform
    unless %w[active inactive].include?(@to)
      raise Error.new("That office status is not valid.", code: :invalid)
    end
    if @to == @office.status
      return
    end
    if @to == "inactive" && @agency.offices.active.where.not(id: @office.id).none?
      raise Error.new("An agency must keep at least one active office.", code: :last_office)
    end

    previous = @office.status
    @office.update!(status: @to)
    apply_deactivation_fan_out! if @office.inactive?

    audit!(
      agency: @agency,
      action: @to == "inactive" ? "office.deactivated" : "office.reactivated",
      subject: @office,
      details: {
        "office_id" => @office.id,
        "office_code" => @office.code,
        "reason" => @reason,
        "previous_status" => previous,
        "status" => @office.status
      },
      **actor_audit_args
    )
  end

  def apply_deactivation_fan_out!
    assignments = @office.office_assignments.active.order(:agency_membership_id, :id).lock.to_a
    lost_default = assignments.select(&:is_default?)

    assignments.each do |assignment|
      assignment.update!(is_default: false) if assignment.is_default?
    end

    lost_default.each do |assignment|
      nominate_remaining_default!(assignment.agency_membership)
    end
  end

  def nominate_remaining_default!(membership)
    remaining = membership.accessible_offices.where.not(id: @office.id)
    return unless remaining.one?

    GrantOfficeAccess.new(
      agency: @agency,
      membership: membership,
      office: remaining.first,
      make_default: true,
      actor: @actor,
      actor_identifier: @actor_identifier,
      privileged: @privileged
    ).call
  end
end
