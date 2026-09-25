# frozen_string_literal: true

class HotelStaysController < ApplicationController
  include SupplierArrangementAccess

  before_action :require_slice3_access!
  before_action :set_departure
  before_action :set_supplier_arrangement

  def show
    assign_workspace
  end

  def supplier_component
    mutate("Supplier cost saved.") do
      RecordHotelSupplierComponent.new(
        agency: Current.agency, actor: Current.agency_user, arrangement: @supplier_arrangement,
        idempotency_key: params[:idempotency_key], attributes: component_params
      ).call
    end
  end

  def milestone
    mutate("Deadline saved.") do
      RecordHotelMilestone.new(
        agency: Current.agency, actor: Current.agency_user, arrangement: @supplier_arrangement,
        idempotency_key: params[:idempotency_key], attributes: milestone_params
      ).call
    end
  end

  def deposit
    mutate("Deposit saved.") do
      RecordHotelDeposit.new(
        agency: Current.agency, actor: Current.agency_user, arrangement: @supplier_arrangement,
        idempotency_key: params[:idempotency_key], attributes: deposit_params
      ).call
    end
  end

  def service_connection
    mutate("Service connection saved.") do
      ConnectHotelServiceOffer.new(
        agency: Current.agency, actor: Current.agency_user, arrangement: @supplier_arrangement,
        idempotency_key: params[:idempotency_key], attributes: connection_params
      ).call
    end
  end

  def room_category
    mutate("Room category saved.") do
      AddHotelRoomCategory.new(
        agency: Current.agency, actor: Current.agency_user, arrangement: @supplier_arrangement,
        idempotency_key: params[:idempotency_key], version_lock_version: params[:version_lock_version],
        attributes: params.permit(:name, :maximum_occupancy, :quantity)
      ).call
    end
  end

  private

  def require_slice3_access!
    raise ActiveRecord::RecordNotFound unless Current.agency_user&.permitted?(:manage_departures)
  end

  def assign_workspace
    @workspace = CompileHotelStayWorkspace.new(agency: Current.agency, arrangement: @supplier_arrangement).call
    @shape = @workspace[:shape]
    @editor = params[:editor].presence
    @idempotency_key = SecureRandom.uuid
  end

  def mutate(notice)
    yield
    redirect_to departure_arrangement_hotel_path(@departure, @supplier_arrangement), status: :see_other, notice: notice
  rescue AgencyCommand::Error => error
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    assign_workspace
    @editor = params[:editor].presence || "component"
    @submitted = params
    @form_error = error.message
    render :show, status: :unprocessable_entity
  end

  def component_params
    params.permit(:arrangement_item_id, :label, :amount, :shape, :percentage, :percentage_treatment, :version_lock_version)
  end

  def milestone_params
    params.permit(:arrangement_item_id, :template, :date, :time_zone, :version_lock_version)
  end

  def deposit_params
    params.permit(:arrangement_item_id, :percentage, :date, :description, :time_zone, :version_lock_version)
  end

  def connection_params
    params.permit(:mode, :title, :description, :arrangement_item_id, :arrangement_lock_version, supplier_resource_ids: [])
  end
end
