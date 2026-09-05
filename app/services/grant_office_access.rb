class GrantOfficeAccess < MembershipCommand
  def initialize(agency:, membership:, office:, make_default: false, actor: nil, actor_identifier: nil, privileged: false)
    @agency = agency
    @membership = membership
    @office = office
    @make_default = make_default
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
      raise Error.new("Office access can only be granted for an active office.", code: :invalid_state)
    end

    assignment = OfficeAssignment.find_or_initialize_by(
      agency: @agency,
      agency_membership: @membership,
      office: @office
    )
    if assignment.persisted?
      assignment.lock!
      assignment.reload
      ensure_assignment_belongs_to_agency!(@agency, assignment)
    end

    was_active = assignment.persisted? && assignment.active?
    clear_other_defaults! if @make_default

    if assignment.new_record?
      assignment.assign_attributes(status: "active", is_default: @make_default, granted_at: Time.current)
      assignment.save!
    else
      assignment.regrant!(make_default: @make_default || assignment.is_default?)
    end

    unless was_active
      audit_access!("office_access.granted", assignment)
    end
    if @make_default && assignment.is_default?
      audit_access!("office_access.default_changed", assignment)
    end

    CommandResult.new(status: :accepted, assignment: assignment, office: @office, membership: @membership)
  rescue ActiveRecord::RecordInvalid => error
    raise Error.new(error.record.errors.full_messages.to_sentence, code: :invalid)
  end

  def clear_other_defaults!
    @membership.office_assignments.active.where(is_default: true).where.not(office_id: @office.id).find_each do |other|
      other.update!(is_default: false)
    end
  end

  def audit_access!(action, assignment)
    audit!(
      agency: @agency,
      action: action,
      subject: assignment,
      details: {
        "office_id" => @office.id,
        "office_code" => @office.code,
        "membership_id" => @membership.id,
        "user_id" => @membership.user_id,
        "is_default" => assignment.is_default?
      },
      **actor_audit_args
    )
  end
end
