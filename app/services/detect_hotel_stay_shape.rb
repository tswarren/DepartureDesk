# frozen_string_literal: true

class DetectHotelStayShape
  Result = Data.define(
    :compatible, :empty, :advanced, :reasons, :version, :item, :item_definition,
    :occurrence, :occurrence_definition
  ) do
    def compatible? = compatible
    def empty? = empty
    def advanced? = advanced
  end

  def initialize(agency:, arrangement:, item_id: nil)
    @agency = agency
    @arrangement = arrangement
    @item_id = item_id
  end

  def call
    version = @arrangement.versions.find_by(status: "draft") || @arrangement.governing_version || @arrangement.versions.order(:version_number).last
    definitions = version&.arrangement_item_definitions&.where(category: "lodging")&.order(:position, :id)&.to_a || []
    definitions.select! { |definition| definition.arrangement_item_id == @item_id } if @item_id.present?
    return empty_result(version) if definitions.empty?
    return advanced_result(version, [ "Hotel setup cannot summarize more than one stay." ]) if definitions.size > 1

    definition = definitions.first
    item = definition.arrangement_item
    occurrences = version.service_occurrence_definitions.where(arrangement_item_id: item.id).order(:id).to_a
    return advanced_result(version, [ "Hotel setup needs one stay schedule." ]) unless occurrences.one?

    reasons = unsupported_cost_reasons(version, item)
    Result.new(
      compatible: reasons.empty?, empty: false, advanced: reasons.any?, reasons: reasons,
      version: version, item: item, item_definition: definition,
      occurrence: occurrences.first.service_occurrence, occurrence_definition: occurrences.first
    )
  end

  private

  def empty_result(version)
    Result.new(
      compatible: false, empty: true, advanced: false, reasons: [], version: version,
      item: nil, item_definition: nil, occurrence: nil, occurrence_definition: nil
    )
  end

  def advanced_result(version, reasons)
    Result.new(
      compatible: false, empty: false, advanced: true, reasons: reasons, version: version,
      item: nil, item_definition: nil, occurrence: nil, occurrence_definition: nil
    )
  end

  def unsupported_cost_reasons(version, item)
    allowed = RecordHotelSupplierComponent::SHAPES.values
    components = SupplierCostComponent.joins(supplier_cost_definition: :supplier_cost_source)
      .where(supplier_cost_sources: { supplier_arrangement_version_id: version.id, arrangement_item_id: item.id })
    return [ "Open advanced Supplier planning for this cost." ] if components.any? { |component|
      component.calculation_kind != "minimum_quantity_shortfall" && allowed.none? { |shape|
        component.calculation_kind == shape[:calculation_kind] &&
          (shape[:quantity_basis].nil? || component.quantity_basis == shape[:quantity_basis])
      }
    }

    []
  end
end
