class SupplierArrangementsController < ApplicationController
  include SupplierArrangementAccess

  before_action :require_departure_view!
  before_action :require_departure_management!, except: %i[index show]
  before_action :set_departure
  before_action :set_supplier_arrangement, only: %i[show edit update edit_abandon abandon]
  before_action :set_initial_version, only: %i[show edit update edit_abandon abandon]

  def index
    @status = ListDepartureArrangements::STATUSES.include?(params[:status]) ? params[:status] : "all"
    @search = ListDepartureArrangements.call(
      agency: Current.agency,
      actor: Current.agency_user,
      departure: @departure,
      q: params[:q],
      status: @status,
      contracting_supplier_id: params[:contracting_supplier_id]
    )
  rescue AgencyCommand::Error => error
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    @search = ListDepartureArrangements::Outcome.new(records: [], truncated: false)
    flash.now[:alert] = error.message
    render :index, status: :unprocessable_entity
  end

  def show
    load_arrangement_graph
  end

  def new
    @supplier_arrangement = @departure.supplier_arrangements.new
    @idempotency_key = SecureRandom.uuid
  end

  def create
    result = CreateSupplierArrangement.new(
      agency: Current.agency,
      actor: Current.agency_user,
      departure: @departure,
      attributes: supplier_arrangement_params,
      idempotency_key: params[:idempotency_key]
    ).call
    redirect_to departure_arrangement_path(@departure, result.record), notice: "Arrangement saved."
  rescue AgencyCommand::Error => error
    @supplier_arrangement = @departure.supplier_arrangements.new(supplier_arrangement_params)
    @idempotency_key = params[:idempotency_key]
    add_arrangement_error(@supplier_arrangement, error)
    render :new, status: :unprocessable_entity
  end

  def edit
  end

  def update
    UpdateSupplierArrangement.new(
      agency: Current.agency,
      actor: Current.agency_user,
      arrangement: @supplier_arrangement,
      attributes: supplier_arrangement_params,
      lock_version: supplier_arrangement_params[:lock_version]
    ).call
    redirect_to departure_arrangement_path(@departure, @supplier_arrangement), notice: "Arrangement updated."
  rescue AgencyCommand::Error => error
    @supplier_arrangement.assign_attributes(supplier_arrangement_params.except(:lock_version, :contracting_supplier_id))
    add_arrangement_error(@supplier_arrangement, error)
    render :edit, status: :unprocessable_entity
  end

  def edit_abandon
    @abandon_reason = params[:reason]
  end

  def abandon
    AbandonSupplierArrangement.new(
      agency: Current.agency,
      actor: Current.agency_user,
      arrangement: @supplier_arrangement,
      reason: params[:reason],
      arrangement_lock_version: params[:arrangement_lock_version],
      version_lock_version: params[:version_lock_version]
    ).call
    redirect_to departure_arrangement_path(@departure, @supplier_arrangement), notice: "Arrangement abandoned."
  rescue AgencyCommand::Error => error
    @abandon_reason = params[:reason]
    add_arrangement_error(@supplier_arrangement_version, error)
    render :edit_abandon, status: :unprocessable_entity
  end

  private

  def supplier_arrangement_params
    params.fetch(:supplier_arrangement, ActionController::Parameters.new).permit(
      :name, :contracting_supplier_id, :supplier_contact_id, :lock_version
    )
  end

  def load_arrangement_graph
    @item_definitions = @supplier_arrangement_version.arrangement_item_definitions
      .includes(:arrangement_item, :default_service_provider)
      .order(:position, :id)
      .to_a
    item_ids = @item_definitions.map(&:arrangement_item_id)
    @occurrence_definitions_by_item_id = @supplier_arrangement_version.service_occurrence_definitions
      .includes(:service_occurrence, :service_provider)
      .where(arrangement_item_id: item_ids)
      .order(Arel.sql("starts_on ASC, CASE WHEN starts_at_local IS NULL THEN 0 ELSE 1 END ASC, starts_at_local ASC NULLS FIRST, lower(name) ASC, id ASC"))
      .group_by(&:arrangement_item_id)
    @resource_definitions_by_item_id = @supplier_arrangement_version.supplier_resource_definitions
      .includes(:supplier_resource)
      .where(arrangement_item_id: item_ids)
      .order(:position, :id)
      .group_by(&:arrangement_item_id)
  end
end
