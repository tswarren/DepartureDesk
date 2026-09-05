class MembershipCommand
  class Error < StandardError
    attr_reader :code

    def initialize(message, code: :invalid)
      super(message)
      @code = code
    end
  end

  ELIGIBLE_INVITE_NOTICE = "If this address is eligible, an invitation will be sent."

  private

  def with_agency_membership_lock(agency, membership = nil)
    agency.with_lock do
      membership&.lock!
      yield
    end
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
    else
      { actor_identifier: @actor_identifier }
    end
  end
end
