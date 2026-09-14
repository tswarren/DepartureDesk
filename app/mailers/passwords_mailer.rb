class PasswordsMailer < ApplicationMailer
  def reset(agency_user, raw_token)
    @agency_user = agency_user
    @agency = agency_user.agency
    @url = edit_password_url(raw_token)
    mail subject: "Reset your password", to: agency_user.email_address
  end
end
