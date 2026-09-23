# frozen_string_literal: true

class SupplierDepositRequirementDefinitionsController < ApplicationController
  include SupplierArrangementAccess

  before_action :require_departure_view!
  before_action :require_departure_management!, except: :index
  before_action :set_departure
  before_action :set_supplier_arrangement
  before_action :set_exact_version
  before_action :set_definition, only: %i[edit update destroy]

  def index
    @definitions = definition_scope.includes(
      :supplier_deposit_requirement_definition_coverage_links,
      :supplier_deposit_requirement_definition_cost_links,
      :supplier_deposit_requirement_definition_contributor_links
    ).order(:position, :id)
    @tranches = if @supplier_arrangement_version.activated? || @supplier_arrangement_version.superseded?
      @supplier_arrangement_version.supplier_deposit_requirement_tranches
        .includes(:governing_deadline_occurrence, :supplier_commitment)
        .order(:materialized_at, :id)
    else
      SupplierDepositRequirementTranche.none
    end
  end

  def new
    @definition = definition_scope.new(
      amount_shape: "fixed_amount",
      precision: "date_only",
      currency: @departure.operating_currency,
      time_zone: @departure.time_zone,
      rule_shape: "fixed_date",
      rule_parameters: {}
    )
    @idempotency_key = SecureRandom.uuid
    load_form_options
  end

  def create
    result = CreateSupplierDepositRequirementDefinition.new(
      agency: Current.agency, actor: Current.agency_user,
      version: @supplier_arrangement_version,
      attributes: definition_params,
      version_lock_version: params[:version_lock_version],
      idempotency_key: params[:idempotency_key]
    ).call
    redirect_to departure_arrangement_version_deposits_path(
      @departure, @supplier_arrangement, @supplier_arrangement_version
    ), notice: "Deposit requirement definition saved."
  rescue AgencyCommand::Error => error
    @definition = definition_scope.new(
      definition_params.except(:coverage_links, :cost_links, :contributor_definition_ids, :rule_parameters)
    )
    @definition.rule_parameters = parse_rule_parameters_for_form
    @idempotency_key = params[:idempotency_key]
    add_definition_error(error)
    load_form_options
    render :new, status: :unprocessable_entity
  end

  def edit
    load_form_options
  end

  def update
    UpdateSupplierDepositRequirementDefinition.new(
      agency: Current.agency, actor: Current.agency_user, definition: @definition,
      attributes: definition_params, lock_version: definition_params[:lock_version]
    ).call
    redirect_to departure_arrangement_version_deposits_path(
      @departure, @supplier_arrangement, @supplier_arrangement_version
    ), notice: "Deposit requirement definition updated."
  rescue AgencyCommand::Error => error
    @definition.assign_attributes(
      definition_params.except(
        :coverage_links, :cost_links, :contributor_definition_ids, :rule_parameters, :lock_version
      )
    )
    @definition.rule_parameters = parse_rule_parameters_for_form
    add_definition_error(error)
    load_form_options
    render :edit, status: :unprocessable_entity
  end

  def destroy
    RemoveSupplierDepositRequirementDefinition.new(
      agency: Current.agency, actor: Current.agency_user, definition: @definition,
      version_lock_version: params[:version_lock_version]
    ).call
    redirect_to departure_arrangement_version_deposits_path(
      @departure, @supplier_arrangement, @supplier_arrangement_version
    ), notice: "Deposit requirement definition removed."
  rescue AgencyCommand::Error => error
    redirect_to departure_arrangement_version_deposits_path(
      @departure, @supplier_arrangement, @supplier_arrangement_version
    ), alert: error.message
  end

  private

  def set_exact_version
    @supplier_arrangement_version = @supplier_arrangement.versions.find(params[:version_id])
  end

  def set_definition
    @definition = definition_scope.find(params[:id])
  end

  def definition_scope
    @supplier_arrangement_version.supplier_deposit_requirement_definitions
  end

  def load_form_options
    @items = @supplier_arrangement_version.arrangement_item_definitions.order(:position, :id)
    @cost_sources = @supplier_arrangement_version.supplier_cost_sources.order(:position, :id)
    @occurrences = @supplier_arrangement_version.service_occurrence_definitions
      .order(:starts_on, :id)
      .map { |row| [ row.name.presence || row.service_occurrence_id, row.service_occurrence_id ] }
    @resources = @supplier_arrangement_version.supplier_resource_definitions
      .order(:position, :id)
      .map { |row| [ row.name.presence || row.supplier_resource_id, row.supplier_resource_id ] }
    pool_labels = @supplier_arrangement_version.capacity_pool_definitions
      .pluck(:capacity_pool_id, :label).to_h
    @capacity_pools = CapacityPool.where(
      agency_id: @supplier_arrangement.agency_id,
      supplier_arrangement_id: @supplier_arrangement.id
    ).order(:id).map { |pool| [ pool_labels[pool.id].presence || pool.id, pool.id ] }
    @contributor_definitions = definition_scope
      .where(amount_shape: "quantity_times_rate", quantity_basis: "capacity_pool_units")
      .order(:position, :id)
    if @definition&.persisted?
      @contributor_definitions = @contributor_definitions
        .where.not(id: @definition.id)
        .where("position < ?", @definition.position)
    end
  end

  def definition_params
    raw = params.fetch(:supplier_deposit_requirement_definition, {}).permit(
      :amount_shape, :fixed_amount_minor_units, :rate_minor_units, :quantity_basis,
      :explicit_quantity, :percentage, :rounding_scope, :target_amount_minor_units,
      :currency, :rule_shape, :precision, :time_zone, :description, :lock_version,
      :fixed_date, :fixed_datetime, :offset_days, :offset_hours,
      :arm1_rule_shape, :arm1_fixed_date, :arm1_fixed_datetime, :arm1_offset_days,
      :arm1_offset_hours, :arm1_milestone_kind,
      :arm2_rule_shape, :arm2_fixed_date, :arm2_fixed_datetime, :arm2_offset_days,
      :arm2_offset_hours, :arm2_milestone_kind,
      contributor_definition_ids: [],
      coverage_links: [ :arrangement_item_id, :service_occurrence_id, :supplier_resource_id, :capacity_pool_id ],
      cost_links: [ :supplier_cost_source_id, :supplier_cost_definition_id, :supplier_cost_component_id ]
    ).to_h
    raw[:rule_parameters] = build_rule_parameters(raw)
    raw[:coverage_links] = Array(raw[:coverage_links]).reject { |row| row.values.all?(&:blank?) }
    raw[:cost_links] = Array(raw[:cost_links]).reject { |row| row.values.all?(&:blank?) }
    raw[:contributor_definition_ids] = Array(raw[:contributor_definition_ids]).reject(&:blank?)
    raw.except(
      "fixed_date", "fixed_datetime", "offset_days", "offset_hours",
      "arm1_rule_shape", "arm1_fixed_date", "arm1_fixed_datetime", "arm1_offset_days",
      "arm1_offset_hours", "arm1_milestone_kind",
      "arm2_rule_shape", "arm2_fixed_date", "arm2_fixed_datetime", "arm2_offset_days",
      "arm2_offset_hours", "arm2_milestone_kind"
    )
  end

  def build_rule_parameters(raw)
    shape = raw["rule_shape"].to_s
    case shape
    when "fixed_date" then { "date" => raw["fixed_date"] }
    when "fixed_local_datetime" then { "datetime" => raw["fixed_datetime"] }
    when "days_before_departure", "days_after_departure" then { "days" => raw["offset_days"] }
    when "hours_before_departure", "hours_after_departure" then { "hours" => raw["offset_hours"] }
    when "earlier_of", "later_of"
      { "arms" => [ arm_parameters(raw, "arm1"), arm_parameters(raw, "arm2") ] }
    else
      {}
    end
  end

  def arm_parameters(raw, prefix)
    shape = raw["#{prefix}_rule_shape"].to_s
    if shape == SupplierDeadlineRuleEvaluator::MILESTONE_SHAPE
      {
        "rule_shape" => shape,
        "rule_parameters" => { "kind" => raw["#{prefix}_milestone_kind"] }
      }
    else
      {
        "rule_shape" => shape,
        "rule_parameters" => case shape
                             when "fixed_date" then { "date" => raw["#{prefix}_fixed_date"] }
                             when "fixed_local_datetime" then { "datetime" => raw["#{prefix}_fixed_datetime"] }
                             when "days_before_departure", "days_after_departure" then { "days" => raw["#{prefix}_offset_days"] }
                             when "hours_before_departure", "hours_after_departure" then { "hours" => raw["#{prefix}_offset_hours"] }
                             else {}
                             end
      }
    end
  end

  def parse_rule_parameters_for_form
    build_rule_parameters(params.fetch(:supplier_deposit_requirement_definition, {}).to_unsafe_h)
  end

  def add_definition_error(error)
    @definition ||= definition_scope.new
    @definition.errors.add(:base, error.message)
  end
end
