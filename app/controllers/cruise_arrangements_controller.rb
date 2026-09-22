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
      @supplier_arrangement.versions.none? { |version| version.draft? }

    return unless @shape.compatible?

    assign_cabin_categories
    @recommended_action =
      if @shape.cabin_category_count.zero?
        "Add a cabin category"
      else
        "Continue Supplier rates in advanced planning, or add another cabin category"
      end
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
end
