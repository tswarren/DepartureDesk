# Supplier cost screens (S-16) need view_supplier_costs (ACC-31). A command
# error that starts with a field's label is shown on that field.
module SupplierMoneyAccess
  extend ActiveSupport::Concern
  include ArrangementAccess

  private

  def require_supplier_cost_view!
    require_permission!(:view_supplier_costs)
  end

  def money_params(scope, fields)
    params.require(scope).permit(*fields.map { |field| field == :unit_shell_ids ? { unit_shell_ids: [] } : field }).to_h
  end

  def redirect_to_money(notice, anchor: "supplier-cost")
    redirect_to departure_arrangement_path(@departure, @arrangement, anchor:), notice:
  end
end
