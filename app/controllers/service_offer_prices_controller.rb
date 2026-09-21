# frozen_string_literal: true

class ServiceOfferPricesController < ApplicationController
  include DepartureAccess

  before_action :require_unpublished_offer_access!
  before_action :set_departure
  before_action :set_service_offer
  before_action :set_editable_draft

  def create
    CreateServiceOfferPriceDefinition.new(
      agency: Current.agency,
      actor: Current.agency_user,
      offer: @service_offer,
      attributes: price_attributes.merge(idempotency_key: params[:idempotency_key]),
      version_lock_version: params[:version_lock_version]
    ).call
    redirect_to departure_service_offer_path(@departure, @service_offer), notice: "Client price saved."
  rescue AgencyCommand::Error => error
    recover_price_form(error, template: :show)
  end

  def update
    UpdateServiceOfferPriceDefinition.new(
      agency: Current.agency,
      actor: Current.agency_user,
      offer: @service_offer,
      attributes: price_attributes,
      version_lock_version: params[:version_lock_version]
    ).call
    redirect_to departure_service_offer_path(@departure, @service_offer), notice: "Client price updated."
  rescue AgencyCommand::Error => error
    recover_price_form(error, template: :show)
  end

  def destroy
    RemoveServiceOfferPriceDefinition.new(
      agency: Current.agency,
      actor: Current.agency_user,
      offer: @service_offer,
      version_lock_version: params[:version_lock_version]
    ).call
    redirect_to departure_service_offer_path(@departure, @service_offer), notice: "Client price removed."
  rescue AgencyCommand::Error => error
    recover_price_form(error, template: :show)
  end

  def preview
    assign_price_preview
    render "service_offers/show"
  end

  private

  def require_unpublished_offer_access!
    raise ActiveRecord::RecordNotFound unless Current.agency_user&.permitted?(:manage_departures)
  end

  def set_service_offer
    @service_offer = @departure.service_offers.find(params[:service_offer_id])
  end

  def set_editable_draft
    @service_offer_version = @service_offer.editable_draft_version ||
      @service_offer.versions.order(version_number: :desc).first ||
      raise(ActiveRecord::RecordNotFound)
    @service_offer_definition = @service_offer_version.definition
    @price_definition = @service_offer_version.association(:price_definition).scope
      .includes(service_offer_price_components: :service_offer_price_component_bases)
      .first
  end

  def recover_price_form(error, template:)
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    @service_offer.errors.add(:base, error.message)
    flash.now[:alert] = error.message
    assign_price_preview
    render "service_offers/#{template}", status: :unprocessable_entity
  end

  def assign_price_preview
    @price_scenario = EvaluateClientPrice::Scenario.build(scenario_params)
    @price_preview = EvaluateClientPrice.new(
      definition: @price_definition,
      scenario: @price_scenario
    ).call if @price_definition || price_attributes[:pattern].present? || Array(price_attributes[:components]).any?

    if Current.agency_user.permitted?(:manage_departures) && boolean_flag(params[:include_economics])
      @indicative_economics = EvaluateIndicativeScenarioEconomics.new(
        agency: Current.agency,
        actor: Current.agency_user,
        offer: @service_offer,
        version: @service_offer_version,
        scenario: @price_scenario,
        price: @price_preview
      ).call
    end
  end

  def price_attributes
    permitted = params.fetch(:price, {}).permit(
      :pattern, :amount, :amount_minor_units, :label, :mode, :zero_price_reason,
      :client_rate_category_key, :occupancy_position_key,
      components: [
        :label, :client_role, :calculation_kind, :amount, :amount_minor_units, :rate, :percentage,
        :quantity_basis, :percentage_treatment, :client_rate_category_key, :occupancy_position_key,
        { bases: [ :base_position, :base_component_id, :direction ] }
      ]
    ).to_h.with_indifferent_access
    raw_components = permitted[:components]
    list = if raw_components.is_a?(Hash)
      raw_components.sort_by { |key, _| key.to_i }.map(&:last)
    else
      Array(raw_components)
    end
    permitted[:components] = list.filter_map do |component|
      component = component.to_h.with_indifferent_access
      next if component[:label].blank? && component[:amount].blank? && component[:percentage].blank? && component[:rate].blank?

      bases = component[:bases]
      base_list = if bases.is_a?(Hash)
        bases.sort_by { |key, _| key.to_i }.map(&:last)
      else
        Array(bases)
      end
      component[:bases] = base_list.select { |base|
        row = base.to_h.with_indifferent_access
        row[:base_position].present? || row[:base_component_id].present?
      }
      component
    end
    permitted
  end

  def scenario_params
    raw = params.fetch(:scenario, {}).permit(
      :persons, :resource_units, :nights, :service_instances, :occupancy_keys,
      :enrollment_denominator,
      occupancy_positions: [ :key, :rate_category, :client_rate_category_key ],
      selected_binding_ids: []
    )
    positions_raw = raw[:occupancy_positions]
    position_list = if positions_raw.respond_to?(:to_unsafe_h) && !positions_raw.is_a?(Array)
      positions_raw.to_unsafe_h.sort_by { |key, _| key.to_i }.map(&:last)
    elsif positions_raw.is_a?(Hash)
      positions_raw.sort_by { |key, _| key.to_i }.map(&:last)
    else
      Array(positions_raw)
    end
    positions = position_list.filter_map do |row|
      position = row.to_h.with_indifferent_access
      next if position[:key].blank? && position[:rate_category].blank? && position[:client_rate_category_key].blank?

      position
    end
    if positions.blank? && raw[:occupancy_keys].present?
      positions = raw[:occupancy_keys].to_s.split(",").map { |key| { key: key.strip } }
    end
    selected_ids = Array(raw[:selected_binding_ids]).compact_blank
    selections = params.dig(:scenario, :alternative_selections)
    if selected_ids.empty? && selections.present?
      selected_ids = selections.to_unsafe_h.values.compact_blank
    end
    raw.to_h.merge(occupancy_positions: positions, selected_binding_ids: selected_ids)
  end

  def boolean_flag(value)
    ActiveModel::Type::Boolean.new.cast(value) == true
  end
end
