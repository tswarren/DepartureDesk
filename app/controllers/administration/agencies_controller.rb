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
        name: agency_params[:name],
        legal_name: agency_params[:legal_name],
        country_code: agency_params[:country_code],
        default_currency: agency_params[:default_currency],
        default_timezone: agency_params[:default_timezone],
        attention_warning_lead_days: agency_params[:attention_warning_lead_days],
        lock_version: agency_params[:lock_version]
      ).call
      redirect_to administration_agency_path, notice: "Agency profile updated."
    rescue AgencyCommand::Error => error
      redirect_to edit_administration_agency_path, alert: error.message
    end

    private

    def agency_params
      params.require(:agency).permit(
        :name, :legal_name, :country_code, :default_currency, :default_timezone,
        :attention_warning_lead_days, :lock_version
      )
    end
  end
end
