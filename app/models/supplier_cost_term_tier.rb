class SupplierCostTermTier < SupplierCostTermDetail
  self.table_name = "supplier_cost_term_tiers"

  belongs_to :supplier_cost_term, inverse_of: :tiers
  monetize :unit_amount_minor_units, as: :unit_amount, with_model_currency: :term_currency

  validates :threshold_quantity, numericality: { only_integer: true, greater_than: 0 }
  validates :unit_amount_minor_units, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  def term_currency
    supplier_cost_term&.currency
  end
end
