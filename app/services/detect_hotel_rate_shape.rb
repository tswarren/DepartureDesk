# frozen_string_literal: true

class DetectHotelRateShape
  Result = Data.define(:inventory, :contexts, :reasons) do
    def blocked?
      inventory.blocked? || reasons.any?
    end

    def supported_contexts
      contexts.select(&:supported?)
    end
  end

  Context = Data.define(
    :cell, :source, :definition, :base, :third, :fourth, :reason, :advanced
  ) do
    def supported?
      reason.nil?
    end

    def date
      cell.date
    end

    def resource_definition
      cell.resource_definition
    end

    def resource_id
      resource_definition.supplier_resource_id
    end

    def occurrence_id
      cell.night_definition&.service_occurrence_id
    end
  end

  def initialize(agency:, arrangement:, version:, item:, departure:, agreement_read: false)
    @agency = agency
    @arrangement = arrangement
    @version = version
    @item = item
    @departure = departure
    @agreement_read = agreement_read
  end

  def call
    inventory = DetectHotelInventoryShape.new(
      agency: @agency, arrangement: @arrangement, version: @version, item: @item
    ).call
    sources = cost_sources
    @matched_source_ids = []
    contexts = inventory.categories.flat_map do |category|
      category.cells.map { |cell| context_for(category, cell, sources) }
    end
    Result.new(inventory: inventory, contexts: contexts, reasons: item_reasons(inventory, sources))
  end

  private

  def cost_sources
    SupplierCostSource
      .where(agency_id: @agency.id, supplier_arrangement_version_id: @version.id, arrangement_item_id: @item.id)
      .includes(supplier_cost_definitions: :supplier_cost_components)
      .order(:position, :id)
      .to_a
  end

  def context_for(category, cell, sources)
    matched = sources.select do |source|
      source.service_occurrence_id.present? &&
        source.service_occurrence_id == cell.night_definition&.service_occurrence_id &&
        source.supplier_resource_id == cell.resource_definition.supplier_resource_id
    end
    @matched_source_ids.concat(matched.map(&:id))
    inventory_reason = category.reason || cell.reason
    inventory_reason = "Record this room night in Room inventory before entering a Supplier rate." if inventory_reason.nil? && (cell.night_definition.nil? || cell.pool_definition.nil?)

    if matched.many?
      return unsupported(cell, "More than one Supplier cost source covers this room night.", advanced: true)
    end

    source = matched.first
    if inventory_reason
      return unsupported(cell, inventory_reason, advanced: source.present?, source: source)
    end
    return empty_context(cell) if source.nil?

    cost_context(cell, source)
  end

  def cost_context(cell, source)
    if source.charging_supplier_id != @arrangement.contracting_supplier_id
      return unsupported(cell, "This Supplier rate uses a cost shape this page cannot edit.", advanced: true, source: source)
    end

    definitions = source.supplier_cost_definitions.to_a
    return agreement_cost_context(cell, source, definitions) if @agreement_read

    definition = definitions.find { |row| row.contracted? && row.calculated? }
    unless definitions.empty? || (definitions.one? && definition)
      return unsupported(cell, "This Supplier rate uses a cost shape this page cannot edit.", advanced: true, source: source)
    end
    if definition && definition.currency != @departure.operating_currency
      return unsupported(cell, "This Supplier rate uses a cost shape this page cannot edit.", advanced: true, source: source, definition: definition)
    end

    classified = classify_components(definition)
    if classified.nil?
      return unsupported(cell, "This Supplier rate uses a cost shape this page cannot edit.", advanced: true, source: source, definition: definition)
    end

    Context.new(
      cell: cell, source: source, definition: definition,
      base: classified[:base], third: classified[:third], fourth: classified[:fourth],
      reason: nil, advanced: false
    )
  end

  def agreement_cost_context(cell, source, definitions)
    return incomplete_rate(cell, source) if definitions.empty?

    candidates = definitions.select { |row| row.calculated? && row.currency == @departure.operating_currency }
    if candidates.empty?
      return unsupported(cell, "This Supplier rate uses a cost shape this page cannot present.", advanced: true, source: source)
    end

    ready = candidates.select(&:forecast_ready?)
    contracted = ready.select(&:contracted?)
    estimates = ready.select(&:estimate?)
    if contracted.many? || (contracted.empty? && estimates.many?)
      return unsupported(cell, "This Supplier rate uses a cost shape this page cannot present.", advanced: true, source: source)
    end

    definition = contracted.first || estimates.first
    return display_incomplete_rate(cell, source, candidates) if definition.nil?

    classified = classify_components(definition)
    if classified.nil?
      return unsupported(
        cell, "This Supplier rate uses a cost shape this page cannot present.",
        advanced: true, source: source, definition: definition
      )
    end

    Context.new(
      cell: cell, source: source, definition: definition,
      base: classified[:base], third: classified[:third], fourth: classified[:fourth],
      reason: nil, advanced: false
    )
  end

  def display_incomplete_rate(cell, source, candidates)
    working_contracted = candidates.select(&:contracted?)
    working_estimates = candidates.select(&:estimate?)
    if working_contracted.many? || (working_contracted.empty? && working_estimates.many?)
      return unsupported(cell, "This Supplier rate uses a cost shape this page cannot present.", advanced: true, source: source)
    end

    definition = working_contracted.first || working_estimates.first
    return incomplete_rate(cell, source) if definition.nil?

    classified = classify_components(definition)
    if classified.nil?
      return unsupported(
        cell, "This Supplier rate uses a cost shape this page cannot present.",
        advanced: true, source: source, definition: definition
      )
    end

    Context.new(
      cell: cell, source: source, definition: definition,
      base: classified[:base], third: classified[:third], fourth: classified[:fourth],
      reason: "No ready Supplier rate is recorded for this room night.", advanced: false
    )
  end

  def incomplete_rate(cell, source)
    Context.new(
      cell: cell, source: source, definition: nil, base: nil, third: nil, fourth: nil,
      reason: "No ready Supplier rate is recorded for this room night.", advanced: false
    )
  end

  def classify_components(definition)
    return { base: nil, third: nil, fourth: nil } if definition.nil?

    grouped = { base: [], third: [], fourth: [] }
    definition.supplier_cost_components.each do |component|
      kind = component_kind(component)
      return nil if kind.nil?

      grouped[kind] << component
    end
    return nil if grouped.values.any?(&:many?)

    { base: grouped[:base].first, third: grouped[:third].first, fourth: grouped[:fourth].first }
  end

  def component_kind(component)
    return if component.pass_through || !component.supplier_charge? || !component.unit_rate?
    return if component.rate.present? || component.participant_category_id.present?
    return if component.percentage_treatment.present? || component.minimum_minor_units.present? || component.minimum_quantity.present?

    if component.resource_nights? && component.occupancy_position_from.nil? && component.occupancy_position_to.nil?
      :base
    elsif component.occupancy_position_nights? && component.occupancy_position_from == 3 && component.occupancy_position_to == 3
      :third
    elsif component.occupancy_position_nights? && component.occupancy_position_from == 4 && component.occupancy_position_to == 4
      :fourth
    end
  end

  def item_reasons(inventory, sources)
    reasons = []
    reasons.concat(inventory.reasons) if inventory.blocked?
    if sources.any? { |source| !@matched_source_ids.include?(source.id) }
      reasons << "A Supplier cost source is outside the nightly room inventory."
    end
    reasons.uniq
  end

  def empty_context(cell)
    Context.new(cell: cell, source: nil, definition: nil, base: nil, third: nil, fourth: nil, reason: nil, advanced: false)
  end

  def unsupported(cell, reason, advanced:, source: nil, definition: nil)
    Context.new(
      cell: cell, source: source, definition: definition,
      base: nil, third: nil, fourth: nil, reason: reason, advanced: advanced
    )
  end
end
