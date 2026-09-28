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

end
