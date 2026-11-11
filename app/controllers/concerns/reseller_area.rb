# The Reseller namespace (R-01 to R-03; step 9 plan, question 8). Only a
# reseller user of an active relationship is served here; a staff session
# goes back to its own workspace. Every read goes through ResellerScope.
module ResellerArea
  extend ActiveSupport::Concern

  included do
    before_action :require_reseller_session!
    helper_method :reseller_scope
  end

  private

  def reseller_area? = true

  def reseller_scope
    @reseller_scope ||= ResellerScope.new(Current.agency_user)
  end

  def require_reseller_session!
    return if Current.agency_user&.permitted?(:reseller_view_offers) && reseller_scope.active?

    if Current.agency_user&.reseller?
      terminate_session
      redirect_to new_session_path, alert: Authentication::GENERIC_FAILURE
    else
      redirect_to root_path, alert: AgencyCommand::UNAUTHORIZED
    end
  end
end
