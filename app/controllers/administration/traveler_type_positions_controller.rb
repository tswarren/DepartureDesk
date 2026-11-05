module Administration
  class TravelerTypePositionsController < BaseController
    def update
      traveler_type = Current.agency.traveler_types.find(params[:traveler_type_id])
      MoveTravelerType.new(traveler_type:, actor: Current.agency_user, direction: params[:direction]).call
      redirect_to administration_agency_path(anchor: "traveler-types")
    rescue AgencyCommand::Error => error
      redirect_to administration_agency_path(anchor: "traveler-types"), alert: error.message
    end
  end
end
