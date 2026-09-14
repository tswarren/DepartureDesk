class AccountPasswordsController < ApplicationController
  def edit
  end

  def update
    ChangePassword.new(
      agency_user: Current.agency_user,
      current_password: params[:current_password],
      password: params[:password],
      password_confirmation: params[:password_confirmation]
    ).call
    terminate_session
    redirect_to new_session_path, notice: "Password updated. Sign in with the new password."
  rescue AgencyCommand::Error => error
    redirect_to edit_account_password_path, alert: error.message
  end
end
