# frozen_string_literal: true

class CruiseCommercialBenefitsController < ApplicationController
  include SupplierArrangementAccess
  include CruiseAgreementReview

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
    term_type = params[:term_type].presence || benefit_params[:term_type]
    shape = DetectCruiseArrangementShape.new(
      agency: Current.agency,
      arrangement: @supplier_arrangement
    ).call
    existing = shape.version&.supplier_arrangement_commercial_benefit_definitions&.find_by(term_type: term_type)
    citation = if params.fetch(:commercial_benefit, {}).key?(:source_citation)
      benefit_params[:source_citation]
    else
      existing&.source_citation
    end
    RecordCruiseCommercialBenefit.new(
      agency: Current.agency,
      actor: Current.agency_user,
      arrangement: @supplier_arrangement,
      term_type: term_type,
      body: benefit_params[:body],
      source_citation: citation,
      version_lock_version: params.require(:version_lock_version),
      definition_lock_version: params[:definition_lock_version],
      idempotency_key: params[:idempotency_key]
    ).call

    redirect_to agreement_page_path(highlight: "benefit-#{term_type}"),
      notice: "Commercial benefit saved."
  rescue AgencyCommand::Error => error
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    render_agreement_review_error(error, focus: params[:benefit_editor].presence || "benefit-#{term_type}")
  end

  def benefit_params
    params.fetch(:commercial_benefit, ActionController::Parameters.new).permit(
      :term_type, :body, :source_citation
    )
  end
end
