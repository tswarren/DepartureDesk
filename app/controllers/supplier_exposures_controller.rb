# frozen_string_literal: true

class SupplierExposuresController < ApplicationController
  include SupplierArrangementAccess

  before_action :require_departure_view!
  before_action :require_departure_management!, only: %i[rebuild qualify]
  before_action :set_departure
  before_action :set_supplier_arrangement
  before_action :set_governing_version

  def show
    @summaries = @supplier_arrangement.supplier_exposure_summaries
      .order(:qualification_band, :currency, :id)
    @components = @supplier_arrangement.supplier_exposure_components
      .order(:qualification_band, :currency, :source_kind, :id)
    @cost_sources = @supplier_arrangement_version.supplier_cost_sources
      .order(:position, :id).index_by(&:id)
  end

  def rebuild
    RebuildSupplierExposureProjection.new(
      agency: Current.agency,
      actor: Current.agency_user,
      arrangement: @supplier_arrangement
    ).call
    redirect_to departure_arrangement_exposure_path(@departure, @supplier_arrangement),
      notice: "Exposure projection rebuilt from authoritative sources."
  rescue AgencyCommand::Error => error
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    redirect_to departure_arrangement_exposure_path(@departure, @supplier_arrangement),
      alert: error.message
  end

  def qualify
    QualifySupplierContingentExposure.new(
      agency: Current.agency,
      actor: Current.agency_user,
      arrangement: @supplier_arrangement,
      cost_source: params.require(:cost_source_id),
      note: params.require(:note),
      idempotency_key: params.require(:idempotency_key)
    ).call
    redirect_to departure_arrangement_exposure_path(@departure, @supplier_arrangement),
      notice: "Contingent exposure qualified as guaranteed."
  rescue AgencyCommand::Error => error
    raise ActiveRecord::RecordNotFound if error.code == :not_found
    raise if error.code == :unauthorized

    flash.now[:alert] = error.message
    @qualify_cost_source_id = params[:cost_source_id]
    @qualify_note = params[:note]
    @qualify_idempotency_key = params[:idempotency_key]
    show
    render :show, status: :unprocessable_entity
  rescue ActionController::ParameterMissing => error
    flash.now[:alert] = "Enter a qualification note."
    @qualify_cost_source_id = params[:cost_source_id]
    @qualify_note = params[:note]
    @qualify_idempotency_key = params[:idempotency_key].presence || SecureRandom.uuid
    show
    render :show, status: :unprocessable_entity
  end

  private

  def set_governing_version
    @supplier_arrangement_version =
      @supplier_arrangement.governing_version ||
      @supplier_arrangement.versions.order(:version_number, :id).last
    raise ActiveRecord::RecordNotFound if @supplier_arrangement_version.nil?
  end
end
