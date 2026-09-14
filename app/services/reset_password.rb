class ResetPassword < AgencyCommand
  def initialize(token:, password:, password_confirmation:)
    @token = token
    @password = password
    @password_confirmation = password_confirmation
  end

  def call
    user = AgencyUser.find_by(password_reset_token_digest: AgencyUser.digest_token(@token))
    raise Error.new("That password reset is no longer valid.", code: :invalid) unless user && reset_usable?(user)

    ActiveRecord::Base.transaction do
      user.agency.with_lock do
        user.lock!
        user.reload
        raise Error.new("That password reset is no longer valid.", code: :invalid) unless reset_usable?(user)

        user.password = @password
        user.password_confirmation = @password_confirmation
        user.clear_password_reset!
        user.credential_version += 1
        user.save!
        destroy_sessions!(user)
        audit!(agency: user.agency, action: "agency_user.password_reset", subject: user, actor: user, details: { "agency_user_id" => user.id })
      end
    end
    Result.new(status: :accepted, record: user)
  rescue ActiveRecord::RecordInvalid => error
    raise Error.new(error.record.errors.full_messages.to_sentence, code: :invalid)
  end

  private

  def reset_usable?(user)
    user.agency.active? && user.active? && user.password_reset_current?(@token)
  end
end
