module Administration
  class TravelerTypesController < BaseController
    before_action :set_traveler_type, only: %i[edit update]

    def create
      CreateTravelerType.new(agency: Current.agency, actor: Current.agency_user, name: traveler_type_params[:name]).call
      redirect_to administration_agency_path(anchor: "traveler-types"), notice: "Traveler type added."
    rescue AgencyCommand::Error => error
      redirect_to administration_agency_path(anchor: "traveler-types"), alert: error.message
    end

    def edit
    end

    def update
      result = UpdateTravelerType.new(
        traveler_type: @traveler_type,
        actor: Current.agency_user,
        attributes: traveler_type_params.except(:lock_version),
        lock_version: traveler_type_params[:lock_version]
      ).call
      redirect_to administration_agency_path(anchor: "traveler-types"), notice: (result.status == :noop ? "No changes." : "Traveler type updated.")
    rescue AgencyCommand::Error => error
      if traveler_type_params.key?(:name)
        @traveler_type.assign_attributes(name: traveler_type_params[:name])
        @traveler_type.errors.add(:name, error.message)
        render :edit, status: :unprocessable_entity
      else
        redirect_to administration_agency_path(anchor: "traveler-types"), alert: error.message
      end
    end

    private

    def set_traveler_type
      @traveler_type = Current.agency.traveler_types.find(params[:id])
    end

    def traveler_type_params
      params.require(:traveler_type).permit(:name, :status, :counts_as_adult, :lock_version)
    end
  end
end
