# frozen_string_literal: true

class ActivityOfferingsController < ApplicationController
  include SupplierArrangementAccess

  before_action :require_slice3_access!
  before_action :set_departure
  before_action :set_supplier_arrangement

  def show
    assign_workspace
  end

  def supplier_component
    mutate("Supplier cost saved.") do
      RecordActivitySupplierComponent.new(
        agency: Current.agency, actor: Current.agency_user, arrangement: @supplier_arrangement,
        idempotency_key: params[:idempotency_key],
        attributes: params.permit(:arrangement_item_id, :label, :amount, :shape, :minimum_quantity, :version_lock_version)
      ).call
    end
  end

  def milestone
    mutate("Deadline saved.") do
      RecordActivityMilestone.new(
        agency: Current.agency, actor: Current.agency_user, arrangement: @supplier_arrangement,
        idempotency_key: params[:idempotency_key],
        attributes: params.permit(:arrangement_item_id, :template, :date, :version_lock_version)
      ).call
    end
  end

  def service_connection
    mutate("Service connection saved.") do
      ConnectActivityServiceOffer.new(
        agency: Current.agency, actor: Current.agency_user, arrangement: @supplier_arrangement,
        idempotency_key: params[:idempotency_key],
        attributes: params.permit(:mode, :title, :arrangement_item_id, :arrangement_lock_version)
      ).call
    end
  end

  private

  def require_slice3_access!
    raise ActiveRecord::RecordNotFound unless Current.agency_user&.permitted?(:manage_departures)
  end

  def assign_workspace
    @workspace = CompileActivityWorkspace.new(agency: Current.agency, arrangement: @supplier_arrangement).call
    @shape = @workspace[:shape]
    @editor = params[:editor].presence
    @idempotency_key = SecureRandom.uuid
  end

  def mutate(notice)
    yield
    redirect_to departure_arrangement_activities_path(@departure, @supplier_arrangement), status: :see_other, notice: notice
  rescue AgencyCommand::Error => error
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    assign_workspace
    @editor = params[:editor].presence || "component"
    @submitted = params
    @form_error = error.message
    render :show, status: :unprocessable_entity
  end
end
