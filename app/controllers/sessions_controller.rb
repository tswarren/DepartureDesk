class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[new create]
  rate_limit to: 10, within: 3.minutes, only: :create, by: -> { sign_in_rate_limit_key }, with: -> { redirect_to new_session_path, alert: Authentication::GENERIC_FAILURE }

  def new
  end

  def create
    agency = Agency.find_by(workspace_code: Agency.normalize_workspace_code(params[:workspace_code]))
    agency_user = agency&.agency_users&.find_by(email_address: AgencyUser.normalize_email(params[:email_address]))

    if agency&.active? && agency_user&.active? && agency_user.authenticate(params[:password])
      start_new_session_for agency_user
      redirect_to after_authentication_url
    else
      redirect_to new_session_path, alert: Authentication::GENERIC_FAILURE
    end
  end

  def destroy
    terminate_session
    redirect_to new_session_path, status: :see_other
  end

  private

  def sign_in_rate_limit_key
    [
      request.remote_ip,
      Agency.normalize_workspace_code(params[:workspace_code]),
      AgencyUser.normalize_email(params[:email_address])
    ].join(":")
  end
end
