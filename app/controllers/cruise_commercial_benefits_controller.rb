# frozen_string_literal: true

class CruiseCommercialBenefitsController < ApplicationController
  include SupplierArrangementAccess

  before_action :require_departure_view!
  before_action :require_departure_management!
  before_action :set_departure
  before_action :set_supplier_arrangement

  def create
    save_benefit
  end

  def update
    save_benefit
  end

  private

  def save_benefit
    RecordCruiseCommercialBenefit.new(
      agency: Current.agency,
      actor: Current.agency_user,
      arrangement: @supplier_arrangement,
      term_type: params[:term_type].presence || benefit_params[:term_type],
      body: benefit_params[:body],
      source_citation: benefit_params[:source_citation],
      version_lock_version: params.require(:version_lock_version),
      definition_lock_version: params[:definition_lock_version],
      idempotency_key: params[:idempotency_key]
    ).call

    redirect_to departure_arrangement_cruise_path(@departure, @supplier_arrangement),
      notice: "Commercial benefit saved."
  rescue AgencyCommand::Error => error
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    redirect_to departure_arrangement_cruise_agreement_path(@departure, @supplier_arrangement),
      alert: error.message
  end

  def benefit_params
    params.fetch(:commercial_benefit, ActionController::Parameters.new).permit(
      :term_type, :body, :source_citation
    )
  end
end
