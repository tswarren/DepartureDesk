class RevokeAgencyUserInvitation < AgencyCommand
  def initialize(agency_user:, actor:)
    @agency_user = agency_user
    @actor = actor
  end

  def call
    ActiveRecord::Base.transaction do
      @agency_user.agency.with_lock do
        @agency_user.lock!
        @agency_user.reload
        ensure_permitted!(@actor, :manage_agency_users)
        raise Error.new("Only an invited user can have an invitation revoked.", code: :invalid_state) unless @agency_user.invited?

        @agency_user.clear_invitation!
        @agency_user.status = "closed"
        @agency_user.save!
        audit!(agency: @agency_user.agency, action: "agency_user.invitation_revoked", subject: @agency_user, actor: @actor, details: { "agency_user_id" => @agency_user.id })
      end
    end
    Result.new(status: :accepted, record: @agency_user)
  end
end
