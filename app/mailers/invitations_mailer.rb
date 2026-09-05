class InvitationsMailer < ApplicationMailer
  def invite(membership)
    @membership = membership
    @agency = membership.agency
    @user = membership.user
    @token = membership.invitation_token

    mail to: @user.email_address, subject: "Invitation to #{@agency.name} on DepartureDesk"
  end
end
