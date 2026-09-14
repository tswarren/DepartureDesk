class InvitationsMailer < ApplicationMailer
  def invite(agency_user, raw_token)
    @agency_user = agency_user
    @agency = agency_user.agency
    @url = edit_invitation_acceptance_url(raw_token)
    mail subject: "You are invited to #{@agency.name}", to: agency_user.email_address
  end
end
