class UpdateAgencyUser < AgencyCommand
  def initialize(agency_user:, actor:, user_type:, relationship:, default_office_id:, lock_version:)
    @agency_user = agency_user
    @actor = actor
    @user_type = user_type.presence
    @relationship = relationship
    @default_office_id = default_office_id.presence
    @lock_version = lock_version
  end

  def call
    ActiveRecord::Base.transaction do
      @agency_user.agency.with_lock do
        @agency_user.lock!
        @agency_user.reload
        ensure_permitted!(@actor, :manage_agency_users)
        ensure_fresh_lock!
        office = resolve_office!
        ensure_user_type_change_allowed!
        ensure_not_last_active_administrator!(@agency_user) if demotes_last_administrator?

        removed_permissions = assign_user_type!(@agency_user, @user_type)
        @agency_user.relationship = @relationship
        @agency_user.default_office = office
        @agency_user.save!
        audit!(
          agency: @agency_user.agency,
          action: "agency_user.updated",
          subject: @agency_user,
          actor: @actor,
          details: {
            "agency_user_id" => @agency_user.id,
            "user_type" => @agency_user.user_type,
            "removed_permissions" => removed_permissions,
            "default_office_id" => @agency_user.default_office_id,
            "relationship" => @agency_user.relationship
          }
        )
      end
    end
    Result.new(status: :accepted, record: @agency_user)
  rescue ActiveRecord::RecordInvalid => error
    raise Error.new(error.record.errors.full_messages.to_sentence, code: :invalid)
  end

  private

  def ensure_fresh_lock!
    raise Error.new("This user was updated by someone else.", code: :conflict) if @lock_version.blank?
    return if @agency_user.lock_version == @lock_version.to_i

    raise Error.new("This user was updated by someone else.", code: :conflict)
  end

  def resolve_office!
    return if @default_office_id.blank?

    office = @agency_user.agency.offices.find_by(id: @default_office_id)
    raise Error.new("Choose an office in this agency.", code: :not_found) unless office

    office
  end

  def ensure_user_type_change_allowed!
    return if @user_type.blank? || @user_type == @agency_user.user_type
    raise Error.new("That user type is not available.", code: :invalid) unless @user_type.in?(AgencyUser::STAFF_USER_TYPES)
    return if @agency_user.active? || @agency_user.suspended?

    raise Error.new("That user type change is not allowed.", code: :invalid_state)
  end

  def demotes_last_administrator?
    @user_type.present? &&
      @user_type != "agency_admin" &&
      @agency_user.agency_admin? &&
      @agency_user.active?
  end
end
