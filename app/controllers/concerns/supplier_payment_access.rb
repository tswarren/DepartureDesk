# Supplier payment screens (S-30, S-31): seeing supplier money needs
# view_supplier_costs (ACC-31); recording, applying and reversing a
# supplier payment need Financial records (SMN-18). The Departure is loaded
# through the agency, so another agency's id is not found.
module SupplierPaymentAccess
  extend ActiveSupport::Concern
  include DepartureAccess

  included do
    before_action -> { require_permission!(:view_supplier_costs) }
    before_action -> { require_permission!(:manage_supplier_payments) }
    before_action :set_departure
  end

  private

  def set_supplier
    ids = @departure.supplier_arrangements.live.pluck(:supplier_id)
    @supplier = Current.agency.suppliers.where(id: ids).find(params[:supplier_id])
  end

  def money_tab(notice: nil, alert: nil)
    redirect_to departure_supplier_money_path(@departure, anchor: "supplier-payments"), notice:, alert:
  end
end
