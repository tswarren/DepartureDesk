# S-19: recording that the supplier accepted a request (INV-34, INV-35).
class SupplierReservationAcceptancesController < ApplicationController
  include ArrangementAccess

  LABELS = [ [ :supplier_reference, "Supplier reference" ], [ :responded_on, "Response date" ] ].freeze

  before_action :require_arrangement_view!
  before_action -> { require_permission!(:manage_supplier_reservations) }
  before_action :set_departure
  before_action :set_arrangement
  before_action :set_reservation

  def new
    @values = { "responded_on" => Clock.current.today_in(Current.agency.default_timezone).iso8601 }
  end

  def create
    RecordSupplierReservationAcceptance.new(agency: Current.agency, actor: Current.agency_user, reservation: @reservation,
      attributes: acceptance_params, lock_version: params[:lock_version]).call
    redirect_to departure_arrangement_path(@departure, @arrangement, anchor: "supplier-reservations"), notice: "The supplier's acceptance is recorded."
  rescue AgencyCommand::Error => error
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    @values = acceptance_params
    @error = error.message
    render :new, status: :unprocessable_entity
  end

  private

  def set_reservation
    @reservation = @arrangement.supplier_reservations.find(params[:supplier_reservation_id])
  end

  def acceptance_params = params.fetch(:supplier_reservation, {}).permit(:supplier_reference, :responded_on, :response_note).to_h
end
