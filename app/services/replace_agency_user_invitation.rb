class ReplaceAgencyUserInvitation < AgencyCommand
  def initialize(agency_user:, actor:)
    @agency_user = agency_user
    @actor = actor
  end

  def call
    raw_token = nil
    ActiveRecord::Base.transaction do
      @agency_user.agency.with_lock do
        @agency_user.lock!
        @agency_user.reload
        ensure_permitted!(@actor, :manage_agency_users)
        ensure_active_agency!(@agency_user.agency)
        raise Error.new("Only an invited user can receive a replacement invitation.", code: :invalid_state) unless @agency_user.invited?

        raw_token = @agency_user.issue_invitation_token
        @agency_user.save!
        audit!(agency: @agency_user.agency, action: "agency_user.invitation_replaced", subject: @agency_user, actor: @actor, details: { "agency_user_id" => @agency_user.id })
      end
    end
    InvitationsMailer.invite(@agency_user, raw_token).deliver_later
    Result.new(status: :accepted, record: @agency_user)
  end
end
