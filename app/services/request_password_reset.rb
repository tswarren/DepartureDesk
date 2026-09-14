class RequestPasswordReset < AgencyCommand
  GENERIC_RESPONSE = "If that account can reset its password, we sent instructions."

  def initialize(workspace_code:, email_address:)
    @workspace_code = workspace_code
    @email_address = email_address
  end

  def call
    agency = Agency.find_by(workspace_code: Agency.normalize_workspace_code(@workspace_code))
    user = agency&.agency_users&.find_by(email_address: AgencyUser.normalize_email(@email_address))
    if user&.active? && agency.active?
      raw = nil
      ActiveRecord::Base.transaction do
        user.agency.with_lock do
          user.lock!
          user.reload
          if user.active? && user.agency.active?
            raw = user.issue_password_reset_token
            user.save!
          end
        end
      end
      PasswordsMailer.reset(user, raw).deliver_later if raw
    end
    Result.new(status: :accepted, record: nil)
  end
end
