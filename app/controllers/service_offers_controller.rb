# frozen_string_literal: true

class ServiceOffersController < ApplicationController
  include DepartureAccess

  before_action :require_unpublished_offer_access!
  before_action :set_departure
  before_action :set_service_offer, only: %i[show edit update edit_discard discard]
  before_action :set_editable_draft, only: %i[show edit update edit_discard discard]

  def index
    @search = ListDepartureServiceOffers.call(
      agency: Current.agency, actor: Current.agency_user, departure: @departure
    )
  rescue AgencyCommand::Error => error
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    @search = ListDepartureServiceOffers::Outcome.new(records: [], truncated: false)
    flash.now[:alert] = error.message
    render :index, status: :unprocessable_entity
  end

  def show
    @compatibility = EvaluateServiceOfferSourceCompatibility.new(
      agency: Current.agency, actor: Current.agency_user, offer: @service_offer, version: @service_offer_version
    ).call if @service_offer_version.definition&.m3_backed?
    assign_default_price_preview
  end

  def new
    @service_offer = @departure.service_offers.new
    @idempotency_key = SecureRandom.uuid
  end

  def new_from_source
    @idempotency_key = SecureRandom.uuid
    @query = params[:q]
    @search = SearchDepartureOfferSources.call(
      agency: Current.agency, actor: Current.agency_user, departure: @departure, q: @query
    )
    @selected = selected_candidate(@search.records)
    @service_offer = @departure.service_offers.new(
      name: @selected ? source_title_for(@selected) : nil
    )
  rescue AgencyCommand::Error => error
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    @search = SearchDepartureOfferSources::Outcome.new(records: [], truncated: false)
    @service_offer = @departure.service_offers.new
    flash.now[:alert] = error.message
    render :new_from_source, status: :unprocessable_entity
  end

  def create_from_source
    result = CreateServiceOfferFromSource.new(
      agency: Current.agency,
      actor: Current.agency_user,
      departure: @departure,
      attributes: decode_source_key(from_source_params).merge(idempotency_key: params[:idempotency_key])
    ).call
    redirect_to departure_service_offer_path(@departure, result.record), notice: "Service offer draft saved."
  rescue AgencyCommand::Error => error
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    @idempotency_key = params[:idempotency_key].presence || SecureRandom.uuid
    @query = params[:q]
    @search = SearchDepartureOfferSources.call(
      agency: Current.agency, actor: Current.agency_user, departure: @departure, q: @query
    )
    @selected = selected_candidate(@search.records)
    @service_offer = @departure.service_offers.new(name: from_source_params[:name], client_title: from_source_params[:client_title])
    @service_offer.errors.add(:base, error.message)
    flash.now[:alert] = error.message
    render :new_from_source, status: :unprocessable_entity
  end

  def create
    result = CreateServiceOfferWithExplicitBasis.new(
      agency: Current.agency,
      actor: Current.agency_user,
      departure: @departure,
      attributes: explicit_basis_params.merge(idempotency_key: params[:idempotency_key])
    ).call
    redirect_to departure_service_offer_path(@departure, result.record), notice: "Service offer draft saved."
  rescue AgencyCommand::Error => error
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    @idempotency_key = params[:idempotency_key].presence || SecureRandom.uuid
    @service_offer = @departure.service_offers.new(name: explicit_basis_params[:name])
    @service_offer.errors.add(:base, error.message)
    @service_offer.assign_attributes(
      name: explicit_basis_params[:name]
    )
    flash.now[:alert] = error.message
    render :new, status: :unprocessable_entity
  end

  def edit
    assign_default_price_preview
  end

  def update
    UpdateServiceOfferDraft.new(
      agency: Current.agency,
      actor: Current.agency_user,
      offer: @service_offer,
      attributes: update_params,
      offer_lock_version: params.dig(:service_offer, :lock_version),
      version_lock_version: params[:version_lock_version]
    ).call
    redirect_to departure_service_offer_path(@departure, @service_offer), notice: "Service offer draft updated."
  rescue AgencyCommand::Error => error
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    @service_offer.assign_attributes(name: update_params[:name])
    @service_offer.errors.add(:base, error.message)
    flash.now[:alert] = error.message
    render :edit, status: :unprocessable_entity
  end

  def edit_discard
  end

  def discard
    DiscardServiceOfferDraft.new(
      agency: Current.agency,
      actor: Current.agency_user,
      offer: @service_offer,
      reason: params[:reason],
      offer_lock_version: params[:offer_lock_version],
      version_lock_version: params[:version_lock_version]
    ).call
    redirect_to departure_path(@departure), notice: "Service offer draft discarded."
  rescue AgencyCommand::Error => error
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    @service_offer_version.errors.add(:base, error.message)
    @discard_reason = params[:reason]
    flash.now[:alert] = error.message
    render :edit_discard, status: :unprocessable_entity
  end

  def sources
    @query = params[:q]
    @search = SearchDepartureOfferSources.call(
      agency: Current.agency, actor: Current.agency_user, departure: @departure, q: @query
    )
    render :sources
  rescue AgencyCommand::Error => error
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    @search = SearchDepartureOfferSources::Outcome.new(records: [], truncated: false)
    flash.now[:alert] = error.message
    render :sources, status: :unprocessable_entity
  end

  private

  def require_unpublished_offer_access!
    raise ActiveRecord::RecordNotFound unless Current.agency_user&.permitted?(:manage_departures)
  end

  def set_service_offer
    @service_offer = @departure.service_offers.find(params[:id])
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

  def assign_default_price_preview
    @price_scenario ||= EvaluateClientPrice::Scenario.build(
      persons: 2,
      resource_units: 1,
      nights: 7,
      service_instances: 1,
      occupancy_positions: [ { key: "first" }, { key: "second" } ]
    )
    @price_preview = EvaluateClientPrice.new(
      definition: @price_definition,
      scenario: @price_scenario
    ).call if @price_definition
  end

  def from_source_params
    params.fetch(:service_offer, {}).permit(
      :name, :client_title, :client_description, :source_key,
      :supplier_arrangement_id, :supplier_arrangement_version_id,
      :arrangement_item_id, :service_occurrence_id, :supplier_resource_id, :capacity_pool_id,
      :use_tentative_draft
    )
  end

  def explicit_basis_params
    params.fetch(:service_offer, {}).permit(:name, :client_title, :client_description, :fulfillment_basis)
  end

  def update_params
    params.fetch(:service_offer, {}).permit(
      :name, :client_title, :client_description, :refresh_bindings, :reselect_current_sources
    )
  end

  def decode_source_key(attrs)
    key = attrs[:source_key].to_s
    return attrs if key.blank?

    arrangement_id, version_id, item_id, occurrence_id, resource_id, pool_id, tentative = key.split(":")
    attrs.merge(
      supplier_arrangement_id: blank_to_nil(arrangement_id),
      supplier_arrangement_version_id: blank_to_nil(version_id),
      arrangement_item_id: blank_to_nil(item_id),
      service_occurrence_id: blank_to_nil(occurrence_id),
      supplier_resource_id: blank_to_nil(resource_id),
      capacity_pool_id: blank_to_nil(pool_id),
      use_tentative_draft: tentative == "1"
    )
  end

  def blank_to_nil(value)
    value.presence
  end

  def selected_candidate(records)
    key = params.dig(:service_offer, :source_key).to_s
    if key.present?
      records.find { |candidate| offer_source_key(candidate) == key } || records.first
    else
      records.first
    end
  end

  def offer_source_key(candidate)
    [
      candidate.arrangement.id,
      candidate.version.id,
      candidate.item.id,
      candidate.occurrence&.id,
      candidate.resource&.id,
      candidate.pool&.id,
      candidate.tentative ? "1" : "0"
    ].join(":")
  end

  def source_title_for(candidate)
    candidate.occurrence_definition&.name.presence || candidate.item_definition.name
  end
end
