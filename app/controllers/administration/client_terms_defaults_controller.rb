module Administration
  # The agency's reusable client terms wording and default cancellation
  # tiers (BKG-28, BKG-31).
  class ClientTermsDefaultsController < BaseController
    def show
      @agency = Current.agency
      @tiers = @agency.agency_cancellation_tiers.ordered
    end

    def update
      UpdateClientTermsDefaults.new(agency: Current.agency, actor: Current.agency_user, wording: params.dig(:agency, :client_terms_wording),
        lock_version: params.dig(:agency, :lock_version)).call
      redirect_to administration_client_terms_defaults_path, notice: "Client terms wording saved."
    rescue AgencyCommand::Error => error
      redirect_to administration_client_terms_defaults_path, alert: error.message
    end
  end
end
