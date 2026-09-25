# frozen_string_literal: true

class CompileActivityWorkspace
  def initialize(agency:, arrangement:)
    @agency = agency
    @arrangement = arrangement
  end

  def call
    shape = DetectActivityOfferingShape.new(agency: @agency, arrangement: @arrangement).call
    {
      shape: shape,
      offerings: shape.offerings.map { |offering| row_for(shape.version, offering) }
    }
  end

  private

  def row_for(version, offering)
    component = SupplierCostComponent.joins(supplier_cost_definition: :supplier_cost_source)
      .where(supplier_cost_sources: { supplier_arrangement_version_id: version.id, arrangement_item_id: offering.item.id })
      .order(:created_at).first
    minimum = SupplierCostComponent.joins(supplier_cost_definition: :supplier_cost_source)
      .where(supplier_cost_sources: { supplier_arrangement_version_id: version.id, arrangement_item_id: offering.item.id }, calculation_kind: "minimum_quantity_shortfall")
      .first
    offer = CruiseServiceConnectionSupport.offers_pinning_item(offering.item).first
    {
      item_id: offering.item.id,
      name: offering.item_definition.name,
      template: offering.template,
      date: offering.occurrence_definition&.starts_on,
      amount: component&.amount_minor_units,
      minimum: minimum&.minimum_quantity,
      connection: offer ? "Connected" : "Not started"
    }
  end
end
