class SupplierGuaranteeExposureReporter
  MonetaryItem = Data.define(:stage, :record, :economic_item_key, :amount_minor_units, :currency)
  CapacityItem = Data.define(:position, :capacity_unit, :guaranteed, :consumed, :unsold_guaranteed)
  Report = Data.define(:monetary_items, :monetary_totals_by_currency, :guaranteed_capacity_by_unit)

  def self.call(agency:, departure:)
    new(agency:, departure:).call
  end

  def initialize(agency:, departure:)
    @agency = agency
    @departure = departure
  end

  def call
    monetary_items = exposure_keys.filter_map { |key| monetary_item_for(key) }
    capacity_items = capacity_positions.map do |position|
      CapacityItem.new(
        position:,
        capacity_unit: position.capacity_unit,
        guaranteed: position.guaranteed,
        consumed: position.consumed,
        unsold_guaranteed: [ position.guaranteed - position.consumed, 0 ].max
      )
    end

    Report.new(
      monetary_items:,
      monetary_totals_by_currency: monetary_items.group_by(&:currency).transform_values { |items| items.sum(&:amount_minor_units) },
      guaranteed_capacity_by_unit: capacity_items.group_by(&:capacity_unit).transform_values { |items| items.sum(&:unsold_guaranteed) }
    )
  end

  private

  def exposure_keys
    (commitment_keys + guarantee_term_keys).uniq
  end

  def commitment_keys
    SupplierCommitment.open
      .where(agency: @agency, departure: @departure)
      .distinct
      .pluck(:economic_item_key)
  end

  def guarantee_term_keys
    SupplierCostTerm.active
      .where(agency: @agency, departure: @departure)
      .where("shape = 'minimum_guarantee' OR quantity_basis ILIKE '%guarantee%' OR cost_category ILIKE '%guarantee%'")
      .distinct
      .pluck(:economic_item_key)
  end

  def monetary_item_for(key)
    controlling = SupplierEconomicItemPrecedence.controlling_for(agency: @agency, economic_item_key: key)
    return unless controlling
    return unless controlling.record.departure_id == @departure.id

    MonetaryItem.new(
      stage: controlling.stage,
      record: controlling.record,
      economic_item_key: key,
      amount_minor_units: controlling.valuation.amount_minor_units,
      currency: controlling.valuation.currency
    )
  end

  def capacity_positions
    SupplierCapacityPosition
      .where(agency: @agency, departure: @departure)
      .where("guaranteed > 0")
      .includes(:resource, :service_occurrence)
  end
end
