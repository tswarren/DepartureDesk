# frozen_string_literal: true

class CompileDmcItemTable
  FAMILIES = {
    "lodging" => "Hotel",
    "ground_transportation" => "Transportation",
    "activity_attraction" => "Activity",
    "dining" => "Meal",
    "cruise" => "Cruise"
  }.freeze

  def initialize(agency:, arrangement:)
    @agency = agency
    @arrangement = arrangement
  end

  def call
    version = @arrangement.versions.find_by(status: "draft") || @arrangement.governing_version || @arrangement.versions.order(:version_number).last
    return [] unless version

    version.arrangement_item_definitions.order(:position, :id).map do |definition|
      item = definition.arrangement_item
      occurrence = version.service_occurrence_definitions.find_by(arrangement_item_id: item.id)
      resource = version.supplier_resource_definitions.find_by(arrangement_item_id: item.id)
      component = SupplierCostComponent.joins(supplier_cost_definition: :supplier_cost_source)
        .where(supplier_cost_sources: { supplier_arrangement_version_id: version.id, arrangement_item_id: item.id })
        .where.not(calculation_kind: "minimum_quantity_shortfall").order(:created_at).first
      deadline = version.supplier_deadline_definitions
        .joins(:supplier_deadline_definition_coverage_links)
        .where(supplier_deadline_definition_coverage_links: { arrangement_item_id: item.id })
        .order(:position).first
      offer = CruiseServiceConnectionSupport.offers_pinning_item(item).first
      {
        item_id: item.id,
        name: definition.name,
        family: FAMILIES[definition.category] || "Advanced",
        category: definition.category,
        schedule: occurrence&.starts_on,
        capacity: resource&.maximum_occupancy,
        supplier_cost: component&.amount_minor_units,
        deadline: deadline&.rule_parameters&.dig("date"),
        connection: offer ? "Connected" : "Not started",
        next_action: offer ? "Review connection" : "Connect service",
        advanced: !FAMILIES.key?(definition.category)
      }
    end
  end
end
