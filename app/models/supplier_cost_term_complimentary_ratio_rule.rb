class SupplierCostTermComplimentaryRatioRule < SupplierCostTermDetail
  self.table_name = "supplier_cost_term_complimentary_ratio_rules"

  ROUNDING_RULES = %w[floor ceiling nearest].freeze

  belongs_to :supplier_cost_term, inverse_of: :complimentary_ratio_rules
  monetize :unit_amount_minor_units, as: :unit_amount, with_model_currency: :term_currency

  validates :minimum_qualifying_quantity, :paid_unit_quantity, :complimentary_unit_quantity,
    numericality: { only_integer: true, greater_than: 0 }
  validates :unit_amount_minor_units, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :rounding_rule, inclusion: { in: ROUNDING_RULES }

  def term_currency
    supplier_cost_term&.currency
  end
end
