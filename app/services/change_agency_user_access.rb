class ChangeAgencyUserAccess < AgencyCommand
  def initialize(agency_user:, actor:, access_role: nil, status: nil, lock_version: nil)
    @agency_user = agency_user
    @actor = actor
    @access_role = access_role
    @status = status
    @lock_version = lock_version
  end

  def call
    ActiveRecord::Base.transaction do
      @agency_user.agency.with_lock do
        @agency_user.lock!
        @agency_user.reload
        ensure_permitted!(@actor, :manage_agency_users)
        raise Error.new("This user was updated by someone else.", code: :conflict) if @lock_version.present? && @agency_user.lock_version != @lock_version.to_i
        ensure_not_last_active_administrator!(@agency_user) if demotes_or_deactivates?

        apply_change!
        destroy_sessions!(@agency_user) unless @agency_user.active?
        audit!(
          agency: @agency_user.agency,
          action: audit_action,
          subject: @agency_user,
          actor: @actor,
          details: { "agency_user_id" => @agency_user.id, "access_role" => @agency_user.access_role, "status" => @agency_user.status }
        )
      end
    end
    Result.new(status: :accepted, record: @agency_user)
  end

  private

  def demotes_or_deactivates?
    return true if @status.in?(%w[suspended closed]) && @agency_user.active?
    return true if @access_role.present? && @access_role != "administrator" && @agency_user.role_administrator? && @agency_user.active?

    false
  end

  def apply_change!
    if @access_role.present?
      raise Error.new("That role change is not allowed.", code: :invalid_state) unless @agency_user.active? || @agency_user.suspended?
      @agency_user.access_role = @access_role
    end
    if @status.present?
      unless allowed_status_transition?
        raise Error.new("That user status change is not allowed.", code: :invalid_state)
      end
      @agency_user.status = @status
    end
    @agency_user.save!
  end

  def allowed_status_transition?
    case @agency_user.status
    when "active" then @status.in?(%w[suspended closed])
    when "suspended" then @status.in?(%w[active closed])
    else
      false
    end
  end

  def audit_action
    return "agency_user.role_changed" if @access_role.present? && @status.blank?
    return "agency_user.suspended" if @status == "suspended"
    return "agency_user.reactivated" if @status == "active"
    return "agency_user.closed" if @status == "closed"

    "agency_user.role_changed"
  end
end
