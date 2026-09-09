class SupplierCostTermPerNightDetail < SupplierCostTermDetail
  self.table_name = "supplier_cost_term_per_night_details"

  belongs_to :supplier_cost_term, inverse_of: :per_night_detail
  monetize :unit_amount_minor_units, as: :unit_amount, with_model_currency: :term_currency

  validates :unit_amount_minor_units, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  def term_currency
    supplier_cost_term&.currency
  end
end
