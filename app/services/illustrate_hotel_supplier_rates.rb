# frozen_string_literal: true

class IllustrateHotelSupplierRates
  Row = Data.define(:resource_definition, :date, :amounts)
  Line = Data.define(:resource_definition, :quantity, :total_minor_units)
  Night = Data.define(:date, :lines, :total_minor_units)
  Result = Data.define(:rows, :nights, :total_minor_units)

  def initialize(agency:, departure:, arrangement:, version:, shape:)
    @agency = agency
    @departure = departure
    @arrangement = arrangement
    @version = version
    @shape = shape
  end

  def call
    nights = block_nights
    Result.new(
      rows: occupancy_rows,
      nights: nights,
      total_minor_units: nights.any? && nights.all? { |night| night.total_minor_units } ? nights.sum(&:total_minor_units) : nil
    )
  end

  private

  def occupancy_rows
    priced_contexts.group_by(&:resource_id).flat_map do |_resource_id, contexts|
      priced = contexts
      computed = priced.filter_map do |context|
        amounts = occupancy_amounts(context)
        [ context, amounts ] if amounts
      end
      next [] if computed.empty?

      if computed.size == priced.size && computed.map(&:last).uniq.size == 1
        [ Row.new(resource_definition: priced.first.resource_definition, date: nil, amounts: computed.first.last) ]
      else
        computed.map do |context, amounts|
          Row.new(resource_definition: context.resource_definition, date: context.date, amounts: amounts)
        end
      end
    end
  end

  def priced_contexts
    @shape.contexts.reject(&:advanced).select { |context| context.definition && context.base }
  end

  def occupancy_amounts(context)
    maximum = context.resource_definition.maximum_occupancy.to_i
    return if maximum < 1

    (1..maximum).map do |count|
      total = probe_total(context, units: 1, nights: 1, positions: (1..count).to_a)
      return nil if total.nil?

      total
    end
  end

  def block_nights
    @shape.supported_contexts.group_by(&:date).sort_by { |date, _contexts| date }.map do |date, contexts|
      lines = contexts.filter_map { |context| block_line(context) }
      complete = lines.size == contexts.size
      Night.new(date: date, lines: lines, total_minor_units: complete ? lines.sum(&:total_minor_units) : nil)
    end
  end

  def block_line(context)
    return if context.definition.nil? || context.base.nil? || context.cell.pool_definition.nil?

    quantity = context.cell.pool_definition.proposed_opening_quantity
    total = probe_total(context, units: quantity, nights: 1, positions: [])
    return if total.nil?

    Line.new(resource_definition: context.resource_definition, quantity: quantity, total_minor_units: total)
  end

  def probe_total(context, units:, nights:, positions:)
    profile = EvaluateSupplierCostForecast::PreviewProfile.new(
      id: "hotel-rate-#{context.source.id}-#{units}-#{positions.size}",
      resource_unit_count: units
    )
    position_rows = positions.map do |position|
      EvaluateSupplierCostForecast::EphemeralPosition.new(
        id: position, occupancy_position: position, participant_category_id: nil
      )
    end
    usage = EvaluateSupplierCostForecast::EphemeralUsage.new(
      id: "hotel-rate-usage-#{context.source.id}-#{nights}-#{units}-#{positions.size}",
      expected_persons: nil,
      expected_resource_units: units,
      expected_billable_nights: nights
    )
    rows = EvaluateSupplierCostForecast.new(
      agency: @agency,
      departure: @departure,
      arrangement: @arrangement,
      version: @version,
      probe_definition: context.definition
    ).call_attributed_sources(
      sources: [ context.source ],
      usage: usage,
      profiles: [ profile ],
      positions_by_profile: { profile.id => position_rows }
    )
    row = rows.find { |candidate| candidate.source_id == context.source.id }
    return if row.nil? || !row.complete

    row.totals.forecast_supplier_cost_minor_units
  end
end
