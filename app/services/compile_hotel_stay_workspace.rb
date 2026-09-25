# frozen_string_literal: true

class CompileHotelStayWorkspace
  def initialize(agency:, arrangement:)
    @agency = agency
    @arrangement = arrangement
  end

  def call
    shape = DetectHotelStayShape.new(agency: @agency, arrangement: @arrangement).call
    return { shape: shape, rooms: [], components: [], milestones: [], deposits: [], connection: nil } unless shape.item

    version = shape.version
    item = shape.item
    {
      shape: shape,
      rooms: version.supplier_resource_definitions.where(arrangement_item_id: item.id).order(:position, :id).map { |definition|
        { name: definition.name, occupancy: definition.maximum_occupancy }
      },
      components: cost_rows(version, item),
      milestones: version.supplier_deadline_definitions.order(:position, :id).map { |definition|
        { description: definition.description, date: definition.rule_parameters["date"], type: definition.deadline_type }
      },
      deposits: version.supplier_deposit_requirement_definitions.order(:position, :id).map { |definition|
        { description: definition.description, percentage: definition.percentage, date: definition.rule_parameters["date"] }
      },
      connection: connection_for(item)
    }
  end

  private

  def cost_rows(version, item)
    SupplierCostComponent.joins(supplier_cost_definition: :supplier_cost_source)
      .where(supplier_cost_sources: { supplier_arrangement_version_id: version.id, arrangement_item_id: item.id })
      .order(:created_at)
      .map { |component| { label: component.label, amount: component.amount_minor_units, basis: component.quantity_basis, kind: component.calculation_kind } }
  end

  def connection_for(item)
    offer = CruiseServiceConnectionSupport.offers_pinning_item(item).first
    return { status: "Not started" } unless offer

    basis = offer.editable_draft_version&.definition&.fulfillment_basis
    { status: basis == "undecided" ? "Decide later" : "Connected", name: offer.name }
  end
end
