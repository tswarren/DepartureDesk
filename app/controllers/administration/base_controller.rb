module Administration
  class BaseController < ApplicationController
    before_action :require_administrator

    private

    def require_administrator
      return if Current.agency_membership&.administrator?

      redirect_to root_url, alert: "You are not authorized to do that."
    end
  end
end
