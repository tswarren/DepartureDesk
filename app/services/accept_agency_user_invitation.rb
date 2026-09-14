class AcceptAgencyUserInvitation < AgencyCommand
  def initialize(token:, password:, password_confirmation:)
    @token = token
    @password = password
    @password_confirmation = password_confirmation
  end

  def call
    user = AgencyUser.find_by(invitation_token_digest: AgencyUser.digest_token(@token))
    raise Error.new("That invitation is no longer valid.", code: :invalid) unless user&.invitation_current?(@token)

    ActiveRecord::Base.transaction do
      user.agency.with_lock do
        user.lock!
        user.reload
        raise Error.new("That invitation is no longer valid.", code: :invalid) unless user.invitation_current?(@token)
        raise Error.new("That agency is not active.", code: :invalid_state) unless user.agency.active?

        user.password = @password
        user.password_confirmation = @password_confirmation
        user.status = "active"
        user.clear_invitation!
        user.credential_version += 1
        user.save!
        audit!(
          agency: user.agency,
          action: "agency_user.invitation_accepted",
          subject: user,
          actor: user,
          details: { "agency_user_id" => user.id }
        )
      end
    end
    Result.new(status: :accepted, record: user)
  rescue ActiveRecord::RecordInvalid => error
    raise Error.new(error.record.errors.full_messages.to_sentence, code: :invalid)
  end
end
