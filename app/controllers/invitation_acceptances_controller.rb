class InvitationAcceptancesController < ApplicationController
  allow_unauthenticated_access
  rate_limit to: 10, within: 3.minutes, only: :update

  def edit
  end

  def update
    result = AcceptAgencyUserInvitation.new(
      token: params[:token],
      password: params[:password],
      password_confirmation: params[:password_confirmation]
    ).call
    start_new_session_for result.record
    redirect_to root_path, notice: "Invitation accepted."
  rescue AgencyCommand::Error => error
    redirect_to edit_invitation_acceptance_path(params[:token]), alert: error.message
  end
end
