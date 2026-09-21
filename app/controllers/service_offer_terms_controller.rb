# frozen_string_literal: true

class ServiceOfferTermsController < ApplicationController
  include DepartureAccess

  before_action :require_unpublished_offer_access!
  before_action :set_departure
  before_action :set_service_offer

  def update
    UpdateServiceOfferClientTerms.new(
      agency: Current.agency, actor: Current.agency_user, offer: @service_offer,
      attributes: terms_params, version_lock_version: params[:version_lock_version]
    ).call
    redirect_to departure_service_offer_path(@departure, @service_offer), notice: "Service terms saved."
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

  def terms_params
    params.fetch(:terms, {}).permit(
      :sales_cap_quantity, :sales_cap_basis,
      payment_lines: [ :due_kind, :due_on, :milestone_name, :amount_kind, :amount_minor_units, :percent_rate ],
      cancellation_tiers: [ :threshold_kind, :threshold_on, :days_before, :consequence_kind, :amount_minor_units, :percent_rate, :summary ],
      stated_conditions: [ :condition_kind, :body ]
    )
  end
end
