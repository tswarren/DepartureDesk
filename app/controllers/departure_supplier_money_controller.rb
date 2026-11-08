# The Departure's Supplier money tab (SMN-05, SMN-52): committed cost,
# broken down by arrangement or by booking, and every amount due across
# its arrangements. Views of the same records, never copies. Payments come
# in build step 8.
class DepartureSupplierMoneyController < ApplicationController
  include DepartureAccess

  VIEWS = %w[arrangement booking].freeze

  before_action -> { require_permission!(:view_supplier_costs) }
  before_action :set_departure

  def show
    @view = params[:view].presence_in(VIEWS) || "arrangement"
    @arrangements = @departure.supplier_arrangements.live.includes(:supplier).to_a
    @amounts_due = AmountDue.where(supplier_arrangement: @arrangements).includes(supplier_arrangement: :supplier).by_due
    @cost_lines = CostLine.where(supplier_arrangement: @arrangements)
      .includes(:inventory_group, :base_cost_line, { unit_shells: :inventory_group }, { supplier_arrangement: :supplier },
        client_booking: { client_trip: { client: %i[client_person client_organization] } })
    @commissions = ExpectedCommission.where(supplier_arrangement: @arrangements).includes(client_booking: { client_trip: { client: %i[client_person client_organization] } })
  end
end
