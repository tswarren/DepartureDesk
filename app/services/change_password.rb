class ChangePassword < AgencyCommand
  def initialize(agency_user:, current_password:, password:, password_confirmation:)
    @agency_user = agency_user
    @current_password = current_password
    @password = password
    @password_confirmation = password_confirmation
  end

  def call
    raise Error.new("The current password is not valid.", code: :invalid) unless @agency_user.active? && @agency_user.authenticate(@current_password)

    ActiveRecord::Base.transaction do
      @agency_user.agency.with_lock do
        @agency_user.lock!
        @agency_user.reload
        raise Error.new("The current password is not valid.", code: :invalid) unless @agency_user.active? && @agency_user.authenticate(@current_password)

        @agency_user.password = @password
        @agency_user.password_confirmation = @password_confirmation
        @agency_user.clear_password_reset!
        @agency_user.credential_version += 1
        @agency_user.save!
        destroy_sessions!(@agency_user)
        audit!(
          agency: @agency_user.agency,
          action: "agency_user.password_reset",
          subject: @agency_user,
          actor: @agency_user,
          details: { "agency_user_id" => @agency_user.id, "source" => "password_change" }
        )
      end
    end
    Result.new(status: :accepted, record: @agency_user)
  rescue ActiveRecord::RecordInvalid => error
    raise Error.new(error.record.errors.full_messages.to_sentence, code: :invalid)
  end
end
