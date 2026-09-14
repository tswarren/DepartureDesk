class PasswordsController < ApplicationController
  allow_unauthenticated_access
  rate_limit to: 10, within: 3.minutes, only: :create, by: -> { password_rate_limit_key }, with: -> { redirect_to new_password_path, notice: RequestPasswordReset::GENERIC_RESPONSE }

  def new
  end

  def create
    RequestPasswordReset.new(workspace_code: params[:workspace_code], email_address: params[:email_address]).call
    redirect_to new_session_path, notice: RequestPasswordReset::GENERIC_RESPONSE
  end

  def edit
  end

  def update
    ResetPassword.new(
      token: params[:token],
      password: params[:password],
      password_confirmation: params[:password_confirmation]
    ).call
    redirect_to new_session_path, notice: "Password updated. Sign in with the new password."
  rescue AgencyCommand::Error => error
    redirect_to edit_password_path(params[:token]), alert: error.message
  end

  private

  def password_rate_limit_key
    [
      request.remote_ip,
      Agency.normalize_workspace_code(params[:workspace_code]),
      AgencyUser.normalize_email(params[:email_address])
    ].join(":")
  end
end
