module Administration
  class AgencyLogosController < BaseController
    def update
      UpdateAgencyLogo.new(agency: Current.agency, actor: Current.agency_user, upload: params.require(:agency).require(:logo)).call
      redirect_to administration_agency_path, notice: "Logo updated."
    rescue ActionController::ParameterMissing
      redirect_to edit_administration_agency_path, alert: "Choose a logo file."
    rescue AgencyCommand::Error => error
      redirect_to edit_administration_agency_path, alert: error.message
    end

    def destroy
      UpdateAgencyLogo.new(agency: Current.agency, actor: Current.agency_user, upload: nil).call
      redirect_to administration_agency_path, notice: "Logo removed."
    rescue AgencyCommand::Error => error
      redirect_to edit_administration_agency_path, alert: error.message
    end
  end
end
