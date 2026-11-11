# Invites a reseller user to a reseller relationship (ACC-13; step 9 plan,
# question 3), through the shipped invitation flow. Suspending one stays
# with the Agency Admin's user screens.
class ResellerUsersController < ApplicationController
  ERROR_FIELDS = [ [ :email_address, /email address/i ], [ :first_name, /first name/i ], [ :last_name, /last name/i ] ].freeze

  before_action -> { require_permission!(:manage_reseller_relationships) }
  before_action :set_reseller

  def new
    @agency_user = Current.agency.agency_users.new(user_type: "reseller", reseller: @reseller)
  end

  def create
    result = InviteAgencyUser.new(agency: Current.agency, actor: Current.agency_user, user_type: "reseller", reseller: @reseller,
      email_address: user_params[:email_address], first_name: user_params[:first_name], last_name: user_params[:last_name]).call
    redirect_to reseller_path(@reseller, anchor: "reseller-users"), notice: "Invitation sent to #{result.record.email_address}."
  rescue AgencyCommand::Error => error
    @agency_user = Current.agency.agency_users.new(user_params.merge(user_type: "reseller", reseller: @reseller))
    render_form_error(error, @agency_user, :new, ERROR_FIELDS)
  end

  private

  def set_reseller
    @reseller = Current.agency.resellers.find(params[:reseller_id])
  end

  def user_params
    params.fetch(:agency_user, {}).permit(:email_address, :first_name, :last_name).to_h.symbolize_keys
  end
end
