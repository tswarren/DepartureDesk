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
      profiles: profile_params,
      cells: cell_params,
      custom_rows: custom_row_params,
      overlap_resolution: params[:overlap_resolution],
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
      profiles: profile_params,
      cells: cell_params,
      custom_rows: custom_row_params,
      overlap_resolution: params[:overlap_resolution],
      commission: commission_params,
      stage: params[:stage],
      notes: params[:notes],
      convert_legacy: params[:convert_legacy],
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
    assign_form_from_definition unless @form_cells
    assign_occupancy_from_assumption
  end

  def assign_form_from_definition
    definition = @rate_shape.definition
    @form_stage = definition&.stage || "estimate"
    @form_notes = @rate_shape.source&.notes
    projected = @rate_shape.projected_matrix
    @form_profiles = Array(projected[:profile_details]).presence ||
      Array(projected[:profiles]).map { |key|
        decoded = CruiseSupplierRateSupport.decode_profile_key(key)
        { "key" => key.to_s, "family" => decoded[:family].to_s, "category" => decoded[:category] }
      }
    @form_profile_keys = @form_profiles.map { |profile| (profile[:key] || profile["key"]).to_s }
    @form_custom_rows = Array(projected[:custom_rows]).map(&:with_indifferent_access)
    @form_cells = {}
    currency = definition&.currency || @departure.operating_currency
    Array(projected[:cells]).each do |cell_key, amount_minor|
      @form_cells[cell_key.to_s] = format("%.2f", Money.new(amount_minor, currency).to_f)
    end
    @form_commission = commission_form_from_projected(projected[:commission], currency)
    @form_overlap_resolution = nil
  end

  def commission_form_from_projected(commission, currency)
    commission = (commission || { method: "not_provided" }).with_indifferent_access
    method = commission[:method].to_s
    case method
    when "dollar"
      amounts = {}
      (commission[:amounts] || {}).each do |profile_key, amount_minor|
        amounts[profile_key.to_s] = format("%.2f", Money.new(amount_minor, currency).to_f)
      end
      { method: "dollar", amounts: amounts }
    when "percentage"
      form = {
        method: "percentage",
        shared: commission.key?(:shared) ? commission[:shared] != false : true,
        add_cells: Array(commission[:add_cells]).map(&:to_s),
        subtract_cells: Array(commission[:subtract_cells]).map(&:to_s)
      }
      if form[:shared] == false
        rates = {}
        (commission[:percentages] || commission[:rates] || {}).each do |profile_key, value|
          rates[profile_key.to_s] = if commission[:percentages]
            format("%.4g", value.to_f)
          else
            format("%.4g", value.to_f * 100)
          end
        end
        form[:rates] = rates
      else
        form[:percentage] = format(
          "%.4g",
          commission[:percentage].to_f.nonzero? || (commission[:rate].to_f * 100)
        )
      end
      form
    else
      { method: "not_provided", shared: true }
    end
  end

  def assign_form_from_params
    @form_stage = params[:stage].presence || "estimate"
    @form_notes = params[:notes]
    @form_profiles = profile_params.map { |profile|
      profile.is_a?(Hash) ? profile.stringify_keys : {
        "key" => profile.to_s,
        "family" => CruiseSupplierRateSupport.decode_profile_key(profile)[:family].to_s,
        "category" => CruiseSupplierRateSupport.decode_profile_key(profile)[:category]
      }
    }
    @form_profile_keys = @form_profiles.map { |profile| profile["key"].to_s }
    @form_custom_rows = custom_row_params.map(&:stringify_keys)
    @form_cells = cell_params
    @form_commission = commission_params
    @form_overlap_resolution = params[:overlap_resolution]
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

  def profile_params
    raw = params[:profiles]
    if raw.is_a?(ActionController::Parameters) || (raw.is_a?(Hash) && raw.keys.all? { |k| k.to_s.match?(/\A\d+\z/) })
      Array(raw.to_unsafe_h.sort_by { |k, _| k.to_i }.map(&:last)).filter_map do |entry|
        next if entry.blank?

        data = entry.to_h.with_indifferent_access
        family = (data[:family].presence || CruiseSupplierRateSupport.decode_profile_key(data[:key])[:family]).to_s
        next unless CruiseSupplierRateSupport::PROFILE_FAMILIES.key?(family.to_sym)

        category = data[:category].to_s.strip.presence
        key = data[:key].presence || CruiseSupplierRateSupport.encode_profile_key(family, category: category)
        { family: family, category: category, key: key.to_s }
      end
    else
      keys = Array(raw).filter_map do |entry|
        if entry.is_a?(Hash) || entry.is_a?(ActionController::Parameters)
          data = entry.to_h.with_indifferent_access
          family = (data[:family].presence || CruiseSupplierRateSupport.decode_profile_key(data[:key])[:family]).to_s
          next unless CruiseSupplierRateSupport::PROFILE_FAMILIES.key?(family.to_sym)

          category = data[:category].to_s.strip.presence
          key = data[:key].presence || CruiseSupplierRateSupport.encode_profile_key(family, category: category)
          { family: family, category: category, key: key.to_s }
        else
          decoded = CruiseSupplierRateSupport.decode_profile_key(entry)
          next unless CruiseSupplierRateSupport::PROFILE_FAMILIES.key?(decoded[:family])

          { family: decoded[:family].to_s, category: decoded[:category], key: entry.to_s }
        end
      end
      keys.presence || [
        { family: "first_second", category: nil, key: "first_second" },
        { family: "additional", category: nil, key: "additional" },
        { family: "every_traveler", category: nil, key: "every_traveler" },
        { family: "single_supplement", category: nil, key: "single_supplement" }
      ]
    end
  end

  def custom_row_params
    raw = params[:custom_rows]
    return [] if raw.blank?

    entries = if raw.is_a?(ActionController::Parameters) || raw.is_a?(Hash)
      raw.to_unsafe_h.sort_by { |k, _| k.to_i }.map(&:last)
    else
      Array(raw)
    end
    entries.filter_map do |entry|
      next if entry.blank?

      data = entry.to_h.with_indifferent_access
      next if data[:label].blank?

      {
        key: data[:key].presence || CruiseSupplierRateSupport.slugify_custom_row_key(data[:label]),
        label: data[:label].to_s,
        economic_role: data[:economic_role].presence || "supplier_charge"
      }
    end
  end

  def cell_params
    raw = params.fetch(:cells, {}).permit!.to_h
    custom_keys = custom_row_params.map { |row| row[:key].to_s }
    raw.select do |key, _|
      row_key, profile_key = CruiseSupplierRateSupport.parse_cell_key(key)
      next false if row_key.nil? || profile_key.blank?

      static_or_custom = CruiseSupplierRateSupport::STATIC_ROWS.key?(row_key) || custom_keys.include?(row_key.to_s)
      family = CruiseSupplierRateSupport.decode_profile_key(profile_key)[:family]
      static_or_custom && CruiseSupplierRateSupport::PROFILE_FAMILIES.key?(family)
    end
  end

  def commission_params
    raw = params.fetch(:commission, {}).permit(
      :method, :amount, :applies_per, :percentage, :shared,
      add_cells: [], subtract_cells: [], add_bases: [], subtract_bases: [],
      amounts: {}, rates: {}, percentages: {}
    ).to_h
    raw["add_cells"] = Array(raw["add_cells"].presence || raw["add_bases"]).reject(&:blank?)
    raw["subtract_cells"] = Array(raw["subtract_cells"].presence || raw["subtract_bases"]).reject(&:blank?)
    raw["amounts"] = (raw["amounts"] || {}).to_h
    raw["rates"] = (raw["rates"] || raw["percentages"] || {}).to_h
    raw
  end

  def occupancy_params
    params.fetch(:expected_cabins, {}).permit(:single, :double, :triple).to_h
  end
end
