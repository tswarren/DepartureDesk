class InvitationAcceptancesController < ApplicationController
  allow_unauthenticated_access
  rate_limit to: 10, within: 3.minutes, only: :update, with: -> {
    redirect_to new_session_path, alert: "Try again later."
  }

  def edit
  end

  def update
    result = AcceptInvitation.new(
      token: params[:token],
      password: params[:password],
      password_confirmation: params[:password_confirmation]
    ).call

    start_new_session_for(result.membership.user)
    redirect_to after_authentication_url
  rescue ActiveRecord::RecordInvalid
    flash.now[:alert] = "Passwords did not match or could not be saved."
    render :edit, status: :unprocessable_entity
  rescue MembershipCommand::Error
    redirect_to new_session_path, alert: AcceptInvitation::GENERIC_FAILURE
  end
end
