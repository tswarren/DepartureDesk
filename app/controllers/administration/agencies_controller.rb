module Administration
  class AgenciesController < BaseController
    PROFILE_PARAMS = (UpdateAgencyProfile::ATTRIBUTES + UpdateAgencyProfile::PHONE_ATTRIBUTES).map(&:to_sym).freeze

    def show
      @agency = Current.agency
      load_profile_context
    end

    def edit
      @agency = Current.agency
      load_profile_context
    end

    def update
      UpdateAgencyProfile.new(
        agency: Current.agency,
        actor: Current.agency_user,
        attributes: profile_params,
        inclusions: inclusion_params,
        lock_version: params.dig(:agency, :lock_version)
      ).call
      redirect_to administration_agency_path, notice: "Agency profile updated."
    rescue AgencyCommand::Error => error
      return redirect_to(root_path, alert: error.message) if error.code == :unauthorized

      @agency = Current.agency.reload
      @agency.assign_attributes(profile_params.except(*UpdateAgencyProfile::PHONE_ATTRIBUTES))
      @agency.phone_number = profile_params[:phone_number] if profile_params.key?(:phone_number)
      @agency.phone_extension = profile_params[:phone_extension] if profile_params.key?(:phone_extension)
      @agency.phone_country_code = profile_params[:phone_country_code] if profile_params.key?(:phone_country_code)
      @agency.validate
      add_command_error(error) if @agency.errors.empty?
      @submitted_inclusions = inclusion_params
      load_profile_context
      render :edit, status: :unprocessable_entity
    end

    private

    def load_profile_context
      @document_inclusions = Current.agency.document_inclusions.index_by(&:document_family)
      @traveler_types = Current.agency.traveler_types.ordered
    end

    def profile_params
      params.require(:agency).permit(*PROFILE_PARAMS).to_h
    end

    def inclusion_params
      families = AgencyDocumentInclusion::FAMILIES.index_with { AgencyDocumentInclusion::FIELDS }
      params.fetch(:agency, {}).fetch(:inclusions, {}).permit(families).to_h
    end

    def add_command_error(error)
      if error.message.match?(/telephone/i)
        @agency.errors.add(:phone_number, "is not a valid number for the phone country")
      else
        @agency.errors.add(:base, error.message)
      end
    end
  end
end
