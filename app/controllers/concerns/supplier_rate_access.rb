# The supplier rate grid (S-14, SUP-35). Every rate screen needs the
# ACC-31 cost permissions; changing rates needs Supplier arrangements.
module SupplierRateAccess
  extend ActiveSupport::Concern
  include ArrangementAccess

  included do
    before_action :require_arrangement_view!
    before_action :require_supplier_cost_view!
    before_action :require_arrangement_management!
    before_action :set_departure
    before_action :set_arrangement
  end

  private

  def require_supplier_cost_view! = require_permission!(:view_supplier_costs)

  def rates_path(anchor = nil) = edit_departure_arrangement_rates_path(@departure, @arrangement, anchor:)

  def run_rate_command(anchor, notice)
    result = yield
    redirect_to rates_path(anchor), notice: notice.respond_to?(:call) ? notice.call(result) : notice
  rescue AgencyCommand::Error => error
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    redirect_to rates_path(anchor), alert: error.message
  end
end
