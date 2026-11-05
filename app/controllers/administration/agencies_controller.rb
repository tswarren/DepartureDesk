module Administration
  class AgenciesController < BaseController
    def show
      @agency = Current.agency
    end

    def edit
      @agency = Current.agency
    end

    def update
      UpdateAgencyProfile.new(
        agency: Current.agency,
        actor: Current.agency_user,
        attributes: agency_params.except(:lock_version),
        lock_version: agency_params[:lock_version]
      ).call
      redirect_to administration_agency_path, notice: "Agency profile updated."
    rescue AgencyCommand::Error => error
      redirect_to edit_administration_agency_path, alert: error.message
    end

    private

    def agency_params
      params.require(:agency).permit(:name, :legal_name, :country_code, :default_currency, :default_timezone, :lock_version)
    end
  end
end
