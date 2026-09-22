# frozen_string_literal: true

class InitialPackageOutlinesController < ApplicationController
  include DepartureAccess

  before_action :require_departure_management!
  before_action :set_departure

  def create
    result = CreateInitialPackageWithOutlineServiceOffer.new(
      agency: Current.agency,
      actor: Current.agency_user,
      departure: @departure,
      attributes: outline_params,
      idempotency_key: params[:idempotency_key]
    ).call
    redirect_to departure_path(@departure), notice: "Main package and first component saved."
  rescue AgencyCommand::Error => error
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    flash[:alert] = error.message
    redirect_to departure_path(@departure)
  end

  private

  def outline_params
    params.permit(
      :package_name, :name, :component_name, :client_title, :client_description,
      :client_timing_text, :placement, :idempotency_key
    )
  end
end
