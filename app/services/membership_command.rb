class MembershipCommand
  class Error < StandardError
    attr_reader :code

    def initialize(message, code: :invalid)
      super(message)
      @code = code
    end
  end

  ELIGIBLE_INVITE_NOTICE = "If this address is eligible, an invitation will be sent."
  UNAUTHORIZED = "You are not authorized to do that."

  private

  def assign_command_actors(actor:, actor_identifier:, privileged: false)
    @actor = actor
    @actor_identifier = actor_identifier.to_s.strip.presence
    @privileged = privileged
  end

  def with_agency_membership_lock(agency, membership = nil)
    ensure_actor_shape!
    agency.with_lock do
      agency.reload
      if membership
        membership.lock!
        membership.reload
        ensure_membership_belongs_to_agency!(agency, membership)
      end
      ensure_tenant_actor!(agency)
      yield
    end
  end

  def with_agency_office_lock(agency, office: nil, membership: nil)
    ensure_actor_shape!
    agency.with_lock do
      agency.reload
      if office
        office.lock!
        office.reload
        ensure_office_belongs_to_agency!(agency, office)
      end
      if membership
        membership.lock!
        membership.reload
        ensure_membership_belongs_to_agency!(agency, membership)
      end
      ensure_tenant_actor!(agency)
      yield
    end
  end

  def ensure_actor_shape!
    if @privileged
      if @actor || @actor_identifier.blank?
        raise Error.new(UNAUTHORIZED, code: :unauthorized)
      end
      return
    end

    if @actor.blank? || @actor_identifier.present?
      raise Error.new(UNAUTHORIZED, code: :unauthorized)
    end
  end

  def ensure_tenant_actor!(agency)
    return if @privileged

    membership = @actor.usable_agency_membership
    unless membership &&
        membership.agency_id == agency.id &&
        membership.administrator? &&
        agency.active?
      raise Error.new(UNAUTHORIZED, code: :unauthorized)
    end
  end

  def ensure_membership_belongs_to_agency!(agency, membership)
    return if membership.agency_id == agency.id

    raise Error.new("That membership is not part of this agency.", code: :invalid)
  end

  def ensure_office_belongs_to_agency!(agency, office)
    return if office.agency_id == agency.id

    raise Error.new("That office is not part of this agency.", code: :invalid)
  end

  def ensure_assignment_belongs_to_agency!(agency, assignment)
    return if assignment.agency_id == agency.id

    raise Error.new("That assignment is not part of this agency.", code: :invalid)
  end

  def clear_session_offices_later(office_ids)
    Session.where(office_id: Array(office_ids)).update_all(office_id: nil, updated_at: Time.current)
  end

  def nest_office_access(command)
    command.call
  end

  def active_administrator_count(agency)
    agency.agency_memberships.active.administrator.count
  end

  def ensure_not_last_administrator!(agency, membership)
    return unless membership.administrator? && membership.active?
    return if active_administrator_count(agency) > 1

    raise Error.new("An agency must keep at least one active administrator.", code: :last_administrator)
  end

  def user_has_foreign_active_membership?(user, agency)
    user.active_agency_memberships.where.not(agency_id: agency.id).exists?
  end

  def destroy_sessions_later(user)
    user.sessions.delete_all
  end

  def audit!(agency:, action:, subject:, details: {}, actor: nil, actor_identifier: nil)
    RecordAdministrativeAudit.record(
      agency: agency,
      action: action,
      actor_user: actor,
      actor_identifier: actor_identifier,
      subject: subject,
      details: details
    )
  end

  def actor_audit_args
    if @actor
      { actor: @actor }
    elsif @actor_identifier.present?
      { actor_identifier: @actor_identifier }
    else
      raise Error.new("An actor is required.", code: :unauthorized)
    end
  end
end
