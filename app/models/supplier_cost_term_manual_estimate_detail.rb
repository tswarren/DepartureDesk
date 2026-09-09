class SupplierCostTermManualEstimateDetail < SupplierCostTermDetail
  self.table_name = "supplier_cost_term_manual_estimate_details"

  belongs_to :supplier_cost_term, inverse_of: :manual_estimate_detail
  monetize :forecast_amount_minor_units, as: :forecast_amount, with_model_currency: :term_currency

  normalizes :reason, with: ->(value) { value&.strip }

  validates :forecast_amount_minor_units, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :reason, presence: true

  def term_currency
    supplier_cost_term&.currency
  end
end
