# frozen_string_literal: true

class CruiseArrangementsController < ApplicationController
  include SupplierArrangementAccess

  before_action :require_departure_view!
  before_action :require_departure_management!
  before_action :set_departure
  before_action :set_supplier_arrangement

  def show
    @shape = DetectCruiseArrangementShape.new(
      agency: Current.agency,
      arrangement: @supplier_arrangement
    ).call
    @supplier_arrangement_version = @shape.version
    @editable = @supplier_arrangement_version&.draft?
    @can_create_successor =
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
    assign_cabin_categories
    assign_rate_rows
    @recommended_action =
      if @shape.cabin_category_count.zero?
        "Add a cabin category"
      elsif @rate_rows.any? { |row| row[:summary][:action] == "add" }
        "Add Supplier rates for a cabin category"
      else
        "Continue Supplier rates, or add another cabin category"
      end
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

  def assign_cabin_categories
    version = @shape.version
    resource_definitions = version.supplier_resource_definitions
      .includes(:supplier_resource)
      .order(:position, :id)
      .to_a
    pool_definitions = version.capacity_pool_definitions
      .includes(:capacity_pool)
      .index_by(&:supplier_resource_id)

    @cabin_categories = resource_definitions.map do |resource_definition|
      {
        resource: resource_definition.supplier_resource,
        resource_definition: resource_definition,
        pool_definition: pool_definitions[resource_definition.supplier_resource_id],
        pool: pool_definitions[resource_definition.supplier_resource_id]&.capacity_pool
      }
    end
  end

  def assign_rate_rows
    @rate_rows = @cabin_categories.map do |row|
      shape = DetectCruiseSupplierRateShape.new(
        agency: Current.agency,
        arrangement: @supplier_arrangement,
        resource: row[:resource],
        version: @shape.version
      ).call
      preview = if shape.compatible? && !shape.empty?
        CompileCruiseSupplierRatePreview.new(
          agency: Current.agency,
          arrangement: @supplier_arrangement,
          resource: row[:resource],
          version: @shape.version
        ).call
      end
      {
        resource: row[:resource],
        resource_definition: row[:resource_definition],
        shape: shape,
        summary: shape.summary,
        preview: preview
      }
    end
  end
end
