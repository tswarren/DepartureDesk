class SupplierArrangementsController < ApplicationController
  include SupplierArrangementAccess

  before_action :require_departure_view!
  before_action :require_departure_management!, except: %i[index show search]
  before_action :set_departure
  before_action :set_supplier_arrangement, only: %i[show edit update successor edit_abandon abandon]
  before_action :set_editable_draft_version, only: %i[show edit update edit_abandon abandon]

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

  def search
    @status = SearchSupplierArrangements::STATUSES.include?(params[:status]) ? params[:status] : "all"
    @search = SearchSupplierArrangements.call(
      agency: Current.agency,
      actor: Current.agency_user,
      query: params[:q],
      status: @status,
      contracting_supplier_id: params[:contracting_supplier_id],
      departure_id: params[:filter_departure_id].presence,
      identifier_type: params[:identifier_type]
    )
  rescue AgencyCommand::Error => error
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    @search = SearchSupplierArrangements::Outcome.new(records: [], truncated: false)
    flash.now[:alert] = error.message
    render :search, status: :unprocessable_entity
  end

  def show
    load_arrangement_graph
    @cost_forecast = EvaluateSupplierCostForecast.new(
      agency: Current.agency, departure: @departure, arrangement: @supplier_arrangement
    ).call.arrangements.first
    manageable = Current.agency_user.permitted?(:manage_departures) &&
      (@supplier_arrangement.draft? || @supplier_arrangement.active?) &&
      @supplier_arrangement_version.draft? &&
      (@departure.draft? || @departure.active?) &&
      @supplier_arrangement.contracting_supplier.active?
    @planning_workspace = ArrangementPlanningWorkspace.new(
      departure: @departure,
      arrangement: @supplier_arrangement,
      version: @supplier_arrangement_version,
      item_definitions: @item_definitions,
      occurrence_definitions_by_item_id: @occurrence_definitions_by_item_id,
      resource_definitions_by_item_id: @resource_definitions_by_item_id,
      capacity_pairs_by_item_members: @capacity_pairs_by_item_members,
      capacity_pool_definitions_by_item_pair_id: @capacity_pool_definitions_by_item_pair_id,
      cost_sources_by_item_id: @cost_sources.group_by(&:arrangement_item_id),
      forecast: @cost_forecast,
      manageable: manageable
    )
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

  def successor
    result = CreateSupplierArrangementSuccessor.new(
      agency: Current.agency,
      actor: Current.agency_user,
      arrangement: @supplier_arrangement,
      arrangement_lock_version: params[:arrangement_lock_version],
      version_lock_version: params[:version_lock_version],
      idempotency_key: params[:idempotency_key]
    ).call
    redirect_to departure_arrangement_path(@departure, @supplier_arrangement),
      notice: result.status == :replayed ? "Successor draft already exists." :
        "Successor draft version #{result.record.version_number} created."
  rescue AgencyCommand::Error => error
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    redirect_to departure_arrangement_path(@departure, @supplier_arrangement),
      alert: error.message
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
    successor = @supplier_arrangement.active?
    redirect_to departure_arrangement_path(@departure, @supplier_arrangement),
      notice: successor ? "Successor draft abandoned. The current version remains governing." :
        "Arrangement abandoned."
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
    @capacity_pairs_by_item_members = @supplier_arrangement_version.capacity_pair_definitions
      .includes(capacity_pool_definitions: { capacity_pool: :supplying_supplier })
      .where(arrangement_item_id: item_ids)
      .group_by(&:arrangement_item_id)
      .transform_values { |pairs| pairs.index_by { |pair| [ pair.service_occurrence_id, pair.supplier_resource_id ] } }
    @capacity_pool_definitions_by_item_pair_id = @supplier_arrangement_version.capacity_pool_definitions
      .includes(capacity_pool: :supplying_supplier)
      .where(arrangement_item_id: item_ids)
      .order(:position, :id)
      .group_by(&:arrangement_item_id)
      .transform_values { |definitions| definitions.group_by(&:capacity_pair_definition_id) }
    governing_version = @supplier_arrangement.governing_version
    @effective_capacity_definitions =
      if @supplier_arrangement.active? && governing_version&.activated?
        governing_version.capacity_pool_definitions
          .includes(capacity_pool: :supplying_supplier)
          .joins(:capacity_pool)
          .merge(CapacityPool.where(inventory_mode: %w[block allotment]))
          .order(:position, :id)
          .to_a
      else
        []
      end
    effective_item_ids = @effective_capacity_definitions.map(&:arrangement_item_id).uniq
    @effective_item_definitions_by_id = governing_version&.arrangement_item_definitions
      &.where(arrangement_item_id: effective_item_ids)&.index_by(&:arrangement_item_id) || {}
    @effective_occurrence_definitions_by_id = governing_version&.service_occurrence_definitions
      &.where(arrangement_item_id: effective_item_ids)&.index_by(&:service_occurrence_id) || {}
    @effective_resource_definitions_by_id = governing_version&.supplier_resource_definitions
      &.where(arrangement_item_id: effective_item_ids)&.index_by(&:supplier_resource_id) || {}
    @cost_sources = @supplier_arrangement_version.supplier_cost_sources
      .includes(:charging_supplier, supplier_cost_definitions: [ :supplier_cost_components ])
      .order(Arel.sql("arrangement_item_id NULLS FIRST"), :position, :id)
      .to_a
    @arrangement_cost_sources = @cost_sources.select(&:arrangement_wide?)
    @cost_sources_by_item_id = @cost_sources.reject(&:arrangement_wide?).group_by(&:arrangement_item_id)
    load_deposit_operations!
  end

  def load_deposit_operations!
    version = @supplier_arrangement.governing_version || @supplier_arrangement_version
    @open_deposit_commitments = @supplier_arrangement.supplier_commitments
      .where(opening_kind: "deposit_requirement", supplier_arrangement_version_id: version.id)
      .includes(
        supplier_deposit_requirement_tranche: :governing_deadline_occurrence,
        supplier_commitment_dispositions: :supplier_commitment_reopening
      )
      .order(:opened_at, :id)
      .select(&:open_state?)
    @deposit_attest_idempotency_key = SecureRandom.uuid
    @planning_milestone_idempotency_key = SecureRandom.uuid
  end
end
