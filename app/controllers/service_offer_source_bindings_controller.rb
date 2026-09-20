# frozen_string_literal: true

class ServiceOfferSourceBindingsController < ApplicationController
  include DepartureAccess

  before_action :require_unpublished_offer_access!
  before_action :set_departure
  before_action :set_service_offer
  before_action :set_editable_draft

  def new
    @idempotency_key = SecureRandom.uuid
    @query = params[:q]
    @search = SearchDepartureOfferSources.call(
      agency: Current.agency, actor: Current.agency_user, departure: @departure, q: @query
    )
  end

  def create
    AddServiceOfferSourceBinding.new(
      agency: Current.agency,
      actor: Current.agency_user,
      offer: @service_offer,
      attributes: decode_source_key(binding_params).merge(idempotency_key: params[:idempotency_key]),
      version_lock_version: params[:version_lock_version]
    ).call
    redirect_to departure_service_offer_path(@departure, @service_offer), notice: "Source added."
  rescue AgencyCommand::Error => error
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    @idempotency_key = params[:idempotency_key].presence || SecureRandom.uuid
    @query = params[:q]
    @search = SearchDepartureOfferSources.call(
      agency: Current.agency, actor: Current.agency_user, departure: @departure, q: @query
    )
    @service_offer.errors.add(:base, error.message)
    flash.now[:alert] = error.message
    render :new, status: :unprocessable_entity
  end

  def destroy
    binding = @service_offer_version.source_bindings.find(params[:id])
    RemoveServiceOfferSourceBinding.new(
      agency: Current.agency,
      actor: Current.agency_user,
      offer: @service_offer,
      binding: binding,
      version_lock_version: params[:version_lock_version]
    ).call
    redirect_to departure_service_offer_path(@departure, @service_offer), notice: "Source removed."
  rescue AgencyCommand::Error => error
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    redirect_to departure_service_offer_path(@departure, @service_offer), alert: error.message
  end

  private

  def require_unpublished_offer_access!
    raise ActiveRecord::RecordNotFound unless Current.agency_user&.permitted?(:manage_departures)
  end

  def set_service_offer
    @service_offer = @departure.service_offers.find(params[:service_offer_id])
  end

  def set_editable_draft
    @service_offer_version = @service_offer.editable_draft_version || raise(ActiveRecord::RecordNotFound)
    @service_offer_definition = @service_offer_version.definition
  end

  def binding_params
    params.fetch(:service_offer_source_binding, {}).permit(
      :source_key, :supplier_arrangement_id, :supplier_arrangement_version_id,
      :arrangement_item_id, :service_occurrence_id, :supplier_resource_id, :capacity_pool_id,
      :use_tentative_draft, :membership_kind, :alternative_group_key, :alternative_group_label
    )
  end

  def decode_source_key(attrs)
    key = attrs[:source_key].to_s
    return attrs if key.blank?

    arrangement_id, version_id, item_id, occurrence_id, resource_id, pool_id, tentative = key.split(":")
    attrs.merge(
      supplier_arrangement_id: arrangement_id.presence,
      supplier_arrangement_version_id: version_id.presence,
      arrangement_item_id: item_id.presence,
      service_occurrence_id: occurrence_id.presence,
      supplier_resource_id: resource_id.presence,
      capacity_pool_id: pool_id.presence,
      use_tentative_draft: tentative == "1"
    )
  end
end
