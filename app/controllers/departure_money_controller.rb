# The Departure's Money tab (UX consolidation audit decision 2): client
# money (CMN-06, CMN-29) and supplier money (SMN-05, SMN-52) in two
# sections, kept apart and never netted. Each shows only to staff who may
# see it. Views of the same records, never copies.
class DepartureMoneyController < ApplicationController
  include DepartureAccess

  VIEWS = %w[arrangement booking].freeze

  before_action :require_money_view!
  before_action :set_departure

  def show
    @client_money = client_money if Current.agency_user.permitted?(:view_client_money)
    load_supplier_money if Current.agency_user.permitted?(:view_supplier_costs)
  end

  private

  def require_money_view!
    return if %i[view_client_money view_supplier_costs].any? { |action| Current.agency_user&.permitted?(action) }

    redirect_to root_path, alert: AgencyCommand::UNAUTHORIZED
  end

  def client_money
    Current.agency.client_trips.where(departure: @departure).includes(:departure, { client: %i[client_person client_organization] }, TripMoney::PRELOAD)
      .order(:trip_reference).map { |trip| TripMoney.new(trip) }
  end

  def load_supplier_money
    @view = params[:view].presence_in(VIEWS) || "arrangement"
    @arrangements = @departure.supplier_arrangements.live.includes(:supplier).to_a
    @amounts_due = AmountDue.where(supplier_arrangement: @arrangements).includes(:schedule_line, :payment_applications, supplier_arrangement: :supplier).by_due
    @supplier_payments = @departure.supplier_payments.includes(:supplier, :payee_account, :reversal, :recorded_by, applications: :amount_due)
    @cost_lines = CostLine.where(supplier_arrangement: @arrangements)
      .includes(:inventory_group, :base_cost_line, { unit_shells: :inventory_group }, { supplier_arrangement: :supplier },
        client_booking: { client_trip: { client: %i[client_person client_organization] } })
    @commissions = ExpectedCommission.where(supplier_arrangement: @arrangements).includes(client_booking: { client_trip: { client: %i[client_person client_organization] } })
  end
end
