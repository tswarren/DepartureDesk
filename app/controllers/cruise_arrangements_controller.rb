# frozen_string_literal: true

class CruiseArrangementsController < ApplicationController
  include SupplierArrangementAccess

  before_action :require_departure_view!
  before_action :require_departure_management!, except: :show
  before_action :set_departure
  before_action :set_supplier_arrangement

  def show
    @shape = DetectCruiseArrangementShape.new(
      agency: Current.agency,
      arrangement: @supplier_arrangement
    ).call
    @supplier_arrangement_version = @shape.version
    @can_manage = Current.agency_user.permitted?(:manage_departures)
    @editable = @supplier_arrangement_version&.draft? && @can_manage
    @can_create_successor =
      @can_manage &&
      @departure.active? &&
      @supplier_arrangement.active? &&
      @supplier_arrangement_version&.activated? &&
      @supplier_arrangement.versions.none? { |version| version.draft? }
    @commercial_benefits = commercial_benefit_definitions
    assign_agreement!

    return unless @shape.compatible?

    @connection_workspace = CompileCruiseServiceConnectionWorkspace.new(
      agency: Current.agency,
      arrangement: @supplier_arrangement,
      shape: @shape
    ).call
    @summary = CompileCruiseCompositionSummary.new(
      agency: Current.agency,
      arrangement: @supplier_arrangement,
      shape: @shape
    ).call
  end

  def successor
    result = CreateSupplierArrangementSuccessor.new(
      agency: Current.agency,
      actor: Current.agency_user,
      arrangement: @supplier_arrangement,
      arrangement_lock_version: params[:arrangement_lock_version],
      version_lock_version: params[:version_lock_version],
      idempotency_key: params[:idempotency_key]
    ).call
    redirect_to departure_arrangement_cruise_path(@departure, @supplier_arrangement),
      notice: result.status == :replayed ? "Successor draft already exists." :
        "Successor draft version #{result.record.version_number} created."
  rescue AgencyCommand::Error => error
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    redirect_to departure_arrangement_cruise_path(@departure, @supplier_arrangement),
      alert: error.message
  end

  private

  def assign_agreement!
    version = @supplier_arrangement_version
    @agreement_confirmation = nil
    @agreement_terms = []
    @same_terms_pool_id = nil
    return unless version

    @agreement_confirmation = version.supplier_arrangement_cruise_agreement_confirmations.find_by(current: true)
    @agreement_terms = version.supplier_arrangement_cruise_term_definitions.order(:term_type, :position).to_a
    @same_terms_pool_id = version.capacity_pool_definitions.order(:position, :id).pick(:capacity_pool_id)
  end

  def commercial_benefit_definitions
    return [] unless @shape.compatible? && @supplier_arrangement_version

    @supplier_arrangement_version.supplier_arrangement_commercial_benefit_definitions
      .includes(:copied_from)
      .order(:term_type)
      .to_a
  end

end
