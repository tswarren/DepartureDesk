module Administration
  class BaseController < ApplicationController
    before_action :require_workspace_administration!

    private

    def require_workspace_administration!
      return if Current.agency_user&.permitted?(:manage_agency_profile)

      redirect_to root_path, alert: AgencyCommand::UNAUTHORIZED
    end
  end
end
