# frozen_string_literal: true

class CompileTransportationWorkspace
  def initialize(agency:, arrangement:)
    @agency = agency
    @arrangement = arrangement
  end

  def call
    shape = DetectTransportationShape.new(agency: @agency, arrangement: @arrangement).call
    {
      shape: shape,
      segments: shape.segments.map { |segment| row_for(shape.version, segment) }
    }
  end

  private

  def row_for(version, segment)
    definition = segment.occurrence_definition
    description = definition&.description.to_s
    resource = version.supplier_resource_definitions.find_by(arrangement_item_id: segment.item.id)
    component = SupplierCostComponent.joins(supplier_cost_definition: :supplier_cost_source)
      .where(supplier_cost_sources: { supplier_arrangement_version_id: version.id, arrangement_item_id: segment.item.id })
      .where.not(calculation_kind: "minimum_quantity_shortfall")
      .order(:created_at).first
    offer = CruiseServiceConnectionSupport.offers_pinning_item(segment.item).first
    {
      item_id: segment.item.id,
      name: segment.item_definition.name,
      date: definition&.starts_on,
      pickup: description[/^Pickup: (.+)$/, 1],
      dropoff: description[/^Drop-off: (.+)$/, 1],
      seats: resource&.maximum_occupancy,
      amount: component&.amount_minor_units,
      connection: offer ? "Connected" : "Not started"
    }
  end
end
