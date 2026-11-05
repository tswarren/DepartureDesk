class ChangeAgencyUserAccess < AgencyCommand
  def initialize(agency_user:, actor:, user_type: nil, status: nil, lock_version: nil)
    @agency_user = agency_user
    @actor = actor
    @user_type = user_type
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

        removed_permissions = apply_change!
        destroy_sessions!(@agency_user) unless @agency_user.active?
        audit!(
          agency: @agency_user.agency,
          action: audit_action,
          subject: @agency_user,
          actor: @actor,
          details: {
            "agency_user_id" => @agency_user.id,
            "user_type" => @agency_user.user_type,
            "status" => @agency_user.status,
            "removed_permissions" => removed_permissions
          }
        )
      end
    end
    Result.new(status: :accepted, record: @agency_user)
  end

  private

  def demotes_or_deactivates?
    return true if @status.in?(%w[suspended closed]) && @agency_user.active?
    return true if @user_type.present? && @user_type != "agency_admin" && @agency_user.agency_admin? && @agency_user.active?

    false
  end

  def apply_change!
    removed_permissions = []
    if @user_type.present?
      raise Error.new("That user type change is not allowed.", code: :invalid_state) unless @agency_user.active? || @agency_user.suspended?
      raise Error.new("That user type is not available.", code: :invalid) unless @user_type.in?(AgencyUser::STAFF_USER_TYPES)
      removed_permissions = assign_user_type!(@agency_user, @user_type)
    end
    if @status.present?
      unless allowed_status_transition?
        raise Error.new("That user status change is not allowed.", code: :invalid_state)
      end
      @agency_user.status = @status
    end
    @agency_user.save!
    removed_permissions
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
    return "agency_user.type_changed" if @user_type.present? && @status.blank?
    return "agency_user.suspended" if @status == "suspended"
    return "agency_user.reactivated" if @status == "active"
    return "agency_user.closed" if @status == "closed"

    "agency_user.type_changed"
  end
end
