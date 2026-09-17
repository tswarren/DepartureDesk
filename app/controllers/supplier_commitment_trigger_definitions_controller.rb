class SupplierCommitmentTriggerDefinitionsController < ApplicationController
  include SupplierArrangementAccess

  before_action :require_departure_view!
  before_action :require_departure_management!, except: :index
  before_action :set_departure
  before_action :set_supplier_arrangement
  before_action :set_exact_version
  before_action :set_trigger, only: %i[edit update destroy]

  def index
    @triggers = trigger_scope.includes(
      :committed_supplier, :arrangement_item, :service_occurrence,
      :supplier_resource, :capacity_pool, :supplier_cost_component
    ).order(:position, :id)
  end

  def new
    @trigger = trigger_scope.new
    @idempotency_key = SecureRandom.uuid
    load_form_options
  end

  def create
    result = CreateSupplierCommitmentTriggerDefinition.new(
      agency: Current.agency, actor: Current.agency_user,
      version: @supplier_arrangement_version,
      attributes: trigger_params,
      version_lock_version: params[:version_lock_version],
      idempotency_key: params[:idempotency_key]
    ).call
    redirect_to departure_arrangement_version_commitment_triggers_path(
      @departure, @supplier_arrangement, @supplier_arrangement_version
    ), notice: "Commitment trigger saved."
  rescue AgencyCommand::Error => error
    @trigger = trigger_scope.new(trigger_params)
    @idempotency_key = params[:idempotency_key]
    add_trigger_error(error)
    load_form_options
    render :new, status: :unprocessable_entity
  end

  def edit
    load_form_options
  end

  def update
    UpdateSupplierCommitmentTriggerDefinition.new(
      agency: Current.agency, actor: Current.agency_user, trigger: @trigger,
      attributes: trigger_params, lock_version: trigger_params[:lock_version]
    ).call
    redirect_to departure_arrangement_version_commitment_triggers_path(
      @departure, @supplier_arrangement, @supplier_arrangement_version
    ), notice: "Commitment trigger updated."
  rescue AgencyCommand::Error => error
    @trigger.assign_attributes(trigger_params.except(:lock_version))
    add_trigger_error(error)
    load_form_options
    render :edit, status: :unprocessable_entity
  end

  def destroy
    RemoveSupplierCommitmentTriggerDefinition.new(
      agency: Current.agency, actor: Current.agency_user, trigger: @trigger,
      version_lock_version: params[:version_lock_version]
    ).call
    redirect_to departure_arrangement_version_commitment_triggers_path(
      @departure, @supplier_arrangement, @supplier_arrangement_version
    ), notice: "Commitment trigger removed."
  rescue AgencyCommand::Error => error
    redirect_to departure_arrangement_version_commitment_triggers_path(
      @departure, @supplier_arrangement, @supplier_arrangement_version
    ), alert: error.message
  end

  private

  def set_exact_version
    @supplier_arrangement_version = @supplier_arrangement.versions.find(params[:version_id])
  end

  def set_trigger
    @trigger = trigger_scope.find(params[:id])
  end

  def trigger_scope
    @supplier_arrangement_version.supplier_commitment_trigger_definitions
  end

  def trigger_params
    params.fetch(:supplier_commitment_trigger_definition, {}).permit(
      :trigger_kind, :authority_shape, :description, :committed_supplier_id,
      :arrangement_item_id, :service_occurrence_id, :supplier_resource_id,
      :capacity_pool_id, :fixed_quantity, :quantity_basis,
      :supplier_cost_component_id, :lock_version
    )
  end

  def load_form_options
    @item_definitions = @supplier_arrangement_version.arrangement_item_definitions
      .includes(:arrangement_item).order(:position)
    @occurrence_definitions = @supplier_arrangement_version.service_occurrence_definitions
      .includes(:service_occurrence).order(:starts_on, :name)
    @resource_definitions = @supplier_arrangement_version.supplier_resource_definitions
      .includes(:supplier_resource).order(:position)
    @pool_definitions = @supplier_arrangement_version.capacity_pool_definitions
      .includes(:capacity_pool).order(:position)
    @contracted_components = @supplier_arrangement_version.supplier_cost_components
      .includes(supplier_cost_definition: :supplier_cost_source)
      .joins(:supplier_cost_definition)
      .where(
        economic_role: "supplier_charge",
        supplier_cost_definitions: { stage: "contracted", status: "forecast_ready" }
      ).order(:position)
  end

  def add_trigger_error(error)
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    if error.code == :invalid
      @trigger.errors.add(:base, error.message)
    else
      flash.now[:alert] = error.message
    end
  end
end
