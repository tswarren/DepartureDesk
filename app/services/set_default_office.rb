class SetDefaultOffice < MembershipCommand
  def initialize(agency:, membership:, office:, actor: nil, actor_identifier: nil, privileged: false)
    @agency = agency
    @membership = membership
    @office = office
    assign_command_actors(actor:, actor_identifier:, privileged:)
  end

  def call
    ActiveRecord::Base.transaction do
      with_agency_office_lock(@agency, office: @office, membership: @membership) { perform }
    end
  end

  private

  def perform
    unless @office.active?
      raise Error.new("The default office must be active.", code: :invalid_state)
    end

    assignment = @membership.office_assignments.find_by(office: @office)
    raise Error.new("That office is not assigned.", code: :invalid_state) unless assignment&.active?

    assignment.lock!
    assignment.reload
    return CommandResult.new(status: :accepted, assignment: assignment) if assignment.is_default?

    @membership.office_assignments.active.where(is_default: true).find_each do |other|
      other.update!(is_default: false)
    end
    assignment.update!(is_default: true)

    audit!(
      agency: @agency,
      action: "office_access.default_changed",
      subject: assignment,
      details: {
        "office_id" => @office.id,
        "office_code" => @office.code,
        "membership_id" => @membership.id,
        "user_id" => @membership.user_id
      },
      **actor_audit_args
    )
    CommandResult.new(status: :accepted, assignment: assignment, office: @office, membership: @membership)
  end
end
