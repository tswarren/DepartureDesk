# The Departure's Supplier money tab (SMN-05, SMN-52): every amount due
# across its arrangements, and committed exposure. Views of the same
# records, never copies. Payments come in build step 8.
class DepartureSupplierMoneyController < ApplicationController
  include DepartureAccess

  before_action -> { require_permission!(:view_supplier_costs) }
  before_action :set_departure

  def show
    arrangements = @departure.supplier_arrangements.live
    @amounts_due = AmountDue.where(supplier_arrangement: arrangements).includes(supplier_arrangement: :supplier).by_due
    @cost_lines = CostLine.where(supplier_arrangement: arrangements).includes(supplier_arrangement: :supplier)
  end
end
