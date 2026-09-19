# frozen_string_literal: true

class SupplierDeadlineDefinitionsController < ApplicationController
  include SupplierArrangementAccess

  before_action :require_departure_view!
  before_action :require_departure_management!, except: :index
  before_action :set_departure
  before_action :set_supplier_arrangement
  before_action :set_exact_version
  before_action :set_definition, only: %i[edit update destroy]

  def index
    @definitions = definition_scope.includes(
      :supplier_deadline_definition_coverage_links,
      :supplier_deadline_commitment_definition_lines
    ).order(:position, :id)
    @occurrences = if @supplier_arrangement_version.activated? || @supplier_arrangement_version.superseded?
      @supplier_arrangement_version.supplier_deadline_occurrences
        .includes(:supplier_deadline_projection)
        .order(:materialized_at, :id)
    else
      SupplierDeadlineOccurrence.none
    end
  end

  def new
    @definition = definition_scope.new(
      kind: "informational",
      precision: "date_only",
      cardinality: "one_shared",
      time_zone: @departure.time_zone,
      rule_parameters: {}
    )
    @idempotency_key = SecureRandom.uuid
    load_form_options
  end

  def create
    result = CreateSupplierDeadlineDefinition.new(
      agency: Current.agency, actor: Current.agency_user,
      version: @supplier_arrangement_version,
      attributes: definition_params,
      version_lock_version: params[:version_lock_version],
      idempotency_key: params[:idempotency_key]
    ).call
    redirect_to departure_arrangement_version_deadlines_path(
      @departure, @supplier_arrangement, @supplier_arrangement_version
    ), notice: "Deadline definition saved."
  rescue AgencyCommand::Error => error
    @definition = definition_scope.new(definition_params.except(:coverage_links, :commitment_lines, :rule_parameters))
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
    UpdateSupplierDeadlineDefinition.new(
      agency: Current.agency, actor: Current.agency_user, definition: @definition,
      attributes: definition_params, lock_version: definition_params[:lock_version]
    ).call
    redirect_to departure_arrangement_version_deadlines_path(
      @departure, @supplier_arrangement, @supplier_arrangement_version
    ), notice: "Deadline definition updated."
  rescue AgencyCommand::Error => error
    @definition.assign_attributes(
      definition_params.except(:coverage_links, :commitment_lines, :rule_parameters, :lock_version)
    )
    @definition.rule_parameters = parse_rule_parameters_for_form
    add_definition_error(error)
    load_form_options
    render :edit, status: :unprocessable_entity
  end

  def destroy
    RemoveSupplierDeadlineDefinition.new(
      agency: Current.agency, actor: Current.agency_user, definition: @definition,
      version_lock_version: params[:version_lock_version]
    ).call
    redirect_to departure_arrangement_version_deadlines_path(
      @departure, @supplier_arrangement, @supplier_arrangement_version
    ), notice: "Deadline definition removed."
  rescue AgencyCommand::Error => error
    redirect_to departure_arrangement_version_deadlines_path(
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
    @supplier_arrangement_version.supplier_deadline_definitions
  end

  def definition_params
    raw = params.fetch(:supplier_deadline_definition, {}).permit(
      :deadline_type, :other_label, :kind, :rule_shape, :precision, :time_zone,
      :cardinality, :warning_lead_days, :description, :lock_version,
      :fixed_date, :fixed_datetime, :offset_days, :offset_hours,
      :arm1_rule_shape, :arm1_fixed_date, :arm1_fixed_datetime, :arm1_offset_days, :arm1_offset_hours,
      :arm2_rule_shape, :arm2_fixed_date, :arm2_fixed_datetime, :arm2_offset_days, :arm2_offset_hours,
      coverage_links: [ :arrangement_item_id, :service_occurrence_id, :supplier_resource_id, :capacity_pool_id ],
      commitment_lines: [
        :authority_shape, :description, :committed_supplier_id, :fixed_quantity,
        :quantity_basis, :supplier_cost_component_id
      ]
    )
    attrs = raw.to_h.with_indifferent_access
    attrs[:rule_parameters] = build_rule_parameters(attrs)
    attrs[:coverage_links] = Array(attrs[:coverage_links]).reject { |link|
      link.values_at(
        :arrangement_item_id, :service_occurrence_id, :supplier_resource_id, :capacity_pool_id
      ).all?(&:blank?)
    }
    attrs[:commitment_lines] = Array(attrs[:commitment_lines]).reject { |line|
      line[:authority_shape].blank? && line[:description].blank?
    }
    attrs
  end

  def build_rule_parameters(attrs)
    shape = attrs[:rule_shape].to_s
    case shape
    when "fixed_date"
      { "date" => attrs[:fixed_date] }
    when "fixed_local_datetime"
      { "datetime" => attrs[:fixed_datetime] }
    when "days_before_departure", "days_after_departure"
      { "days" => attrs[:offset_days] }
    when "hours_before_departure", "hours_after_departure"
      { "hours" => attrs[:offset_hours] }
    when "earlier_of", "later_of"
      {
        "arms" => [
          arm_parameters(attrs, "arm1"),
          arm_parameters(attrs, "arm2")
        ]
      }
    else
      {}
    end
  end

  def arm_parameters(attrs, prefix)
    shape = attrs[:"#{prefix}_rule_shape"].to_s
    params = case shape
    when "fixed_date" then { "date" => attrs[:"#{prefix}_fixed_date"] }
    when "fixed_local_datetime" then { "datetime" => attrs[:"#{prefix}_fixed_datetime"] }
    when "days_before_departure", "days_after_departure"
      { "days" => attrs[:"#{prefix}_offset_days"] }
    when "hours_before_departure", "hours_after_departure"
      { "hours" => attrs[:"#{prefix}_offset_hours"] }
    else
      {}
    end
    { "rule_shape" => shape, "rule_parameters" => params }
  end

  def parse_rule_parameters_for_form
    build_rule_parameters(definition_params)
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
        calculation_kind: "fixed",
        supplier_cost_definitions: { stage: "contracted", status: "forecast_ready" }
      ).order(:position)
  end

  def add_definition_error(error)
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    if error.code == :invalid
      @definition.errors.add(:base, error.message)
    else
      flash.now[:alert] = error.message
    end
  end
end
