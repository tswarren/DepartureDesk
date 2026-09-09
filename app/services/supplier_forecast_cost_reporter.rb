class SupplierForecastCostReporter
  Item = Data.define(:stage, :record, :economic_item_key, :amount_minor_units, :currency)
  Report = Data.define(:items, :totals_by_currency)

  def self.call(agency:, departure:)
    new(agency:, departure:).call
  end

  def initialize(agency:, departure:)
    @agency = agency
    @departure = departure
  end

  def call
    items = economic_item_keys.filter_map { |key| item_for(key) }
    Report.new(
      items:,
      totals_by_currency: items.group_by(&:currency).transform_values { |currency_items| currency_items.sum(&:amount_minor_units) }
    )
  end

  private

  def economic_item_keys
    (
      SupplierCostTerm.where(agency: @agency, departure: @departure).distinct.pluck(:economic_item_key) +
        SupplierCommitment.where(agency: @agency, departure: @departure).distinct.pluck(:economic_item_key)
    ).uniq
  end

  def item_for(key)
    controlling = SupplierEconomicItemPrecedence.controlling_for(agency: @agency, economic_item_key: key)
    return unless controlling
    return unless controlling.record.departure_id == @departure.id

    Item.new(
      stage: controlling.stage,
      record: controlling.record,
      economic_item_key: key,
      amount_minor_units: controlling.valuation.amount_minor_units,
      currency: controlling.valuation.currency
    )
  end
end
