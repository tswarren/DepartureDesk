# frozen_string_literal: true

class ServiceOfferChoicesController < ApplicationController
  include DepartureAccess

  before_action :require_unpublished_offer_access!
  before_action :set_departure
  before_action :set_service_offer

  def update
    UpdateServiceOfferChoices.new(
      agency: Current.agency, actor: Current.agency_user, offer: @service_offer,
      attributes: choice_params, version_lock_version: params[:version_lock_version]
    ).call
    redirect_to departure_service_offer_path(@departure, @service_offer), notice: "Choices saved."
  rescue AgencyCommand::Error => error
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    flash[:alert] = error.message
    redirect_to departure_service_offer_path(@departure, @service_offer)
  end

  private

  def require_unpublished_offer_access!
    raise ActiveRecord::RecordNotFound unless Current.agency_user&.permitted?(:manage_departures)
  end

  def set_service_offer
    @service_offer = @departure.service_offers.find(params[:service_offer_id])
  end

  def choice_params
    params.fetch(:choices, {}).permit(
      groups: [
        :name, :min_selections, :max_selections,
        { options: [ :name, :client_description, :price_effect_minor_units,
                     { activation: [ :activation_kind, :service_offer_source_binding_id, :alternative_group_key ] } ] }
      ]
    )
  end
end
