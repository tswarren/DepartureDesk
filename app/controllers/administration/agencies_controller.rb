module Administration
  class AgenciesController < BaseController
    def show
      @agency = Current.agency
    end

    def edit
      @agency = Current.agency
    end

    def update
      @agency = Current.agency
      before = profile_snapshot(@agency)

      ActiveRecord::Base.transaction do
        @agency.assign_attributes(agency_params)
        @agency.save!
        ::RecordAdministrativeAudit.profile_updated(
          agency: @agency,
          actor: Current.user,
          before: before,
          after: profile_snapshot(@agency)
        )
      end

      redirect_to administration_agency_path, notice: "Agency profile updated."
    rescue ActiveRecord::RecordInvalid
      render :edit, status: :unprocessable_entity
    rescue ActiveRecord::StaleObjectError
      submitted = agency_params
      @agency.reload
      @agency.assign_attributes(submitted.except(:lock_version))
      flash.now[:alert] = "This agency was updated by someone else. Review the values and submit again."
      render :edit, status: :conflict
    end

    private

    def agency_params
      params.require(:agency).permit(
        :name,
        :legal_name,
        :country_code,
        :default_timezone,
        :default_currency,
        :lock_version
      )
    end

    def profile_snapshot(agency)
      ::RecordAdministrativeAudit::PROFILE_FIELDS.index_with do |field|
        agency.public_send(field)
      end
    end
  end
end
