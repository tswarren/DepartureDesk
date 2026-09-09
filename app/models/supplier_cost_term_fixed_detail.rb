class SupplierCostTermFixedDetail < SupplierCostTermDetail
  self.table_name = "supplier_cost_term_fixed_details"

  belongs_to :supplier_cost_term, inverse_of: :fixed_detail
  monetize :amount_minor_units, as: :amount, with_model_currency: :term_currency

  validates :amount_minor_units, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  def term_currency
    supplier_cost_term&.currency
  end
end
