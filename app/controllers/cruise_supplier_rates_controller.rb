# frozen_string_literal: true

class CruiseSupplierRatesController < ApplicationController
  include SupplierArrangementAccess

  before_action :require_departure_view!
  before_action :require_departure_management!
  before_action :set_departure
  before_action :set_supplier_arrangement
  before_action :require_compatible_cruise_shape!
  before_action :set_cabin_category
  before_action :require_editable_draft!, only: %i[create update occupancy_plan forecast_readiness]
  before_action :assign_rate_workspace

  def show
  end

  def create
    CreateCruiseSupplierRateSchedule.new(
      agency: Current.agency,
      actor: Current.agency_user,
      arrangement: @supplier_arrangement,
      resource: @supplier_resource,
      terms: terms_params,
      commission: commission_params,
      stage: params[:stage].presence || "estimate",
      notes: params[:notes],
      version_lock_version: params.require(:version_lock_version),
      idempotency_key: params.require(:idempotency_key)
    ).call
    redirect_to departure_arrangement_cruise_cabin_category_supplier_rates_path(
      @departure, @supplier_arrangement, @supplier_resource
    ), notice: "Supplier rates saved."
  rescue AgencyCommand::Error => error
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    @form_error = error.message
    flash.now[:alert] = error.message
    assign_form_from_params
    render :show, status: :unprocessable_entity
  end

  def update
    UpdateCruiseSupplierRateSchedule.new(
      agency: Current.agency,
      actor: Current.agency_user,
      arrangement: @supplier_arrangement,
      resource: @supplier_resource,
      terms: terms_params,
      commission: commission_params,
      stage: params[:stage],
      notes: params[:notes],
      version_lock_version: params.require(:version_lock_version),
      definition_lock_version: params.require(:definition_lock_version),
      idempotency_key: params[:idempotency_key]
    ).call
    redirect_to departure_arrangement_cruise_cabin_category_supplier_rates_path(
      @departure, @supplier_arrangement, @supplier_resource
    ), notice: "Supplier rates updated."
  rescue AgencyCommand::Error => error
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    @form_error = error.message
    flash.now[:alert] = error.message
    assign_form_from_params
    render :show, status: :unprocessable_entity
  end

  def occupancy_plan
    SetCruiseSupplierOccupancyPlan.new(
      agency: Current.agency,
      actor: Current.agency_user,
      arrangement: @supplier_arrangement,
      resource: @supplier_resource,
      expected_cabins: occupancy_params,
      version_lock_version: params.require(:version_lock_version),
      assumption_lock_version: params[:assumption_lock_version]
    ).call
    redirect_to departure_arrangement_cruise_cabin_category_supplier_rates_path(
      @departure, @supplier_arrangement, @supplier_resource
    ), notice: "Occupancy planning saved."
  rescue AgencyCommand::Error => error
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    redirect_to departure_arrangement_cruise_cabin_category_supplier_rates_path(
      @departure, @supplier_arrangement, @supplier_resource
    ), alert: error.message
  end

  def forecast_readiness
    MarkCruiseSupplierRateScheduleForecastReady.new(
      agency: Current.agency,
      actor: Current.agency_user,
      arrangement: @supplier_arrangement,
      resource: @supplier_resource,
      definition_lock_version: params.require(:definition_lock_version),
      readiness_provenance: params[:readiness_provenance],
      confirm_omissions: params[:confirm_omissions]
    ).call
    redirect_to departure_arrangement_cruise_cabin_category_supplier_rates_path(
      @departure, @supplier_arrangement, @supplier_resource
    ), notice: "Supplier rates marked forecast-ready."
  rescue AgencyCommand::Error => error
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    redirect_to departure_arrangement_cruise_cabin_category_supplier_rates_path(
      @departure, @supplier_arrangement, @supplier_resource
    ), alert: error.message
  end

  private

  def require_compatible_cruise_shape!
    @cruise_shape = DetectCruiseArrangementShape.new(
      agency: Current.agency, arrangement: @supplier_arrangement
    ).call
    return if @cruise_shape.compatible?

    redirect_to departure_arrangement_cruise_path(@departure, @supplier_arrangement),
      alert: "Open advanced Supplier planning for this Arrangement."
  end

  def require_editable_draft!
    version = @cruise_shape.version
    return if version&.draft?

    redirect_to departure_arrangement_cruise_path(@departure, @supplier_arrangement),
      alert: "Create a successor draft before editing Supplier rates."
  end

  def set_cabin_category
    version = @cruise_shape.version
    raise ActiveRecord::RecordNotFound unless version

    @resource_definition = version.supplier_resource_definitions
      .includes(:supplier_resource)
      .find_by!(supplier_resource_id: params[:cabin_category_resource_id].presence || params[:resource_id])
    @supplier_resource = @resource_definition.supplier_resource
  end

  def assign_rate_workspace
    @rate_shape = DetectCruiseSupplierRateShape.new(
      agency: Current.agency,
      arrangement: @supplier_arrangement,
      resource: @supplier_resource,
      version: @cruise_shape.version
    ).call
    @preview = CompileCruiseSupplierRatePreview.new(
      agency: Current.agency,
      arrangement: @supplier_arrangement,
      resource: @supplier_resource,
      version: @cruise_shape.version
    ).call
    @editable = @cruise_shape.version&.draft?
    @item = @rate_shape.item || @cruise_shape.item
    @advanced_path = departure_arrangement_item_costs_workspace_path(
      @departure, @supplier_arrangement, @item
    )
    @idempotency_key = SecureRandom.uuid
    assign_form_from_definition unless @form_terms
    assign_occupancy_from_assumption
  end

  def assign_form_from_definition
    definition = @rate_shape.definition
    @form_stage = definition&.stage || "estimate"
    @form_notes = @rate_shape.source&.notes
    @form_terms = {}
    @form_commission = { method: "not_provided" }
    return unless definition

    by_label = definition.supplier_cost_components.index_by(&:label)
    CruiseSupplierRateSupport::CANONICAL_SPECS.each do |key, spec|
      component = by_label[spec.fetch(:label)]
      next unless component

      @form_terms[key] = format("%.2f", Money.new(component.amount_minor_units, definition.currency).to_f)
    end
    commission = by_label[CruiseSupplierRateSupport::COMMISSION_LABEL]
    return unless commission

    if commission.calculation_kind == "unit_rate"
      @form_commission = {
        method: "dollar",
        amount: format("%.2f", Money.new(commission.amount_minor_units, definition.currency).to_f),
        applies_per: commission.quantity_basis == "resource_units" ? "cabin" : "traveler"
      }
    else
      add_bases = []
      subtract_bases = []
      commission.supplier_cost_component_bases.includes(:base_component).each do |link|
        key = CruiseSupplierRateSupport.term_key_for_label(link.base_component.label)
        next unless key

        if link.direction == "subtract"
          subtract_bases << key
        else
          add_bases << key
        end
      end
      @form_commission = {
        method: "percentage",
        percentage: format("%.4g", (commission.rate * 100).to_f),
        add_bases: add_bases,
        subtract_bases: subtract_bases
      }
    end
  end

  def assign_form_from_params
    @form_stage = params[:stage].presence || "estimate"
    @form_notes = params[:notes]
    @form_terms = terms_params
    @form_commission = commission_params
    @form_occupancy = occupancy_params
  end

  def assign_occupancy_from_assumption
    @form_occupancy ||= {}
    return if @rate_shape.item.nil? || @rate_shape.occurrence.nil?

    assumption = @cruise_shape.version.supplier_cost_usage_assumptions.find_by(
      arrangement_item_id: @rate_shape.item.id,
      service_occurrence_id: @rate_shape.occurrence.id,
      supplier_resource_id: @supplier_resource.id
    )
    @assumption = assumption
    return unless assumption

    assumption.supplier_cost_occupancy_profiles.each do |profile|
      key = CruiseSupplierRateSupport::OCCUPANCY_PROFILE_SPECS.find { |_k, spec| spec.fetch(:label) == profile.label }&.first
      @form_occupancy[key] = profile.resource_unit_count if key
    end
  end

  def terms_params
    params.fetch(:terms, {}).permit(*CruiseSupplierRateSupport::CANONICAL_TERM_KEYS).to_h
  end

  def commission_params
    raw = params.fetch(:commission, {}).permit(
      :method, :amount, :applies_per, :percentage, add_bases: [], subtract_bases: []
    ).to_h
    raw["add_bases"] = Array(raw["add_bases"]).reject(&:blank?)
    raw["subtract_bases"] = Array(raw["subtract_bases"]).reject(&:blank?)
    raw
  end

  def occupancy_params
    params.fetch(:expected_cabins, {}).permit(:single, :double, :triple).to_h
  end
end
