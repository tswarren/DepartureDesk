class SupplierCostDefinitionReviewsController < ApplicationController
  include SupplierCostAccess

  before_action :set_cost_source
  before_action :set_cost_definition

  def show
    @components = @supplier_cost_definition.supplier_cost_components
      .includes(:supplier_cost_component_bases).order(:position, :id).to_a
    @components_by_id = @components.index_by(&:id)
    @assumption = @supplier_arrangement_version.supplier_cost_usage_assumptions.find_by(
      arrangement_item_id: @supplier_cost_source.arrangement_item_id,
      service_occurrence_id: @supplier_cost_source.service_occurrence_id,
      supplier_resource_id: @supplier_cost_source.supplier_resource_id
    )
    forecast = EvaluateSupplierCostForecast.new(
      agency: Current.agency, departure: @departure, arrangement: @supplier_arrangement,
      probe_definition: @supplier_cost_definition
    ).call
    @review = forecast.arrangements.first.sources.find do |source|
      source.source_id == @supplier_cost_source.id
    end
    @review_blockers = @review.warnings.map { |warning| warning[:message] }
    if @supplier_cost_definition.calculated? && @components.empty?
      @review_blockers << "Add at least one cost component."
    end
    @components.each do |component|
      if %w[fixed unit_rate].include?(component.calculation_kind) && component.amount_minor_units.to_i <= 0
        @review_blockers << "#{component.label}: amount must be greater than zero."
      elsif component.percentage? && component.rate.to_d <= 0
        @review_blockers << "#{component.label}: percentage must be greater than zero."
      elsif component.minimum_amount_shortfall? && component.minimum_minor_units.to_i <= 0
        @review_blockers << "#{component.label}: minimum amount must be greater than zero."
      end
      if %w[percentage minimum_amount_shortfall].include?(component.calculation_kind) &&
          component.supplier_cost_component_bases.empty?
        @review_blockers << "#{component.label}: select at least one earlier base component."
      end
      if component.minimum_quantity_shortfall? &&
          component.supplier_cost_component_bases.size != 1
        @review_blockers << "#{component.label}: select exactly one compatible earlier unit-rate base."
      end
    end
    @review_blockers.uniq!
    @editable = cost_source_ordinary_editable?(@supplier_cost_source)
  end
end
