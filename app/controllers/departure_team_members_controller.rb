class DepartureTeamMembersController < ApplicationController
  include DepartureAccess

  before_action :require_departure_view!
  before_action :require_departure_management!
  before_action :set_departure

  def create
    run(AddDepartureTeamMember, params.dig(:team_member, :agency_user_id), "Team member added.")
  end

  def destroy
    run(RemoveDepartureTeamMember, params[:id], "Team member removed.")
  end

  def default_owner
    run(SetDepartureDefaultTaskOwner, params[:agency_user_id], "Default task owner updated.")
  end

  private

  def run(command, agency_user_id, notice)
    command.new(agency: Current.agency, actor: Current.agency_user, departure: @departure, agency_user_id:).call
    redirect_to departure_path(@departure, anchor: "team"), notice:
  rescue AgencyCommand::Error => error
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    redirect_to departure_path(@departure, anchor: "team"), alert: error.message
  end
end
