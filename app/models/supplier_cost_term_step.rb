class SupplierCostTermStep < SupplierCostTermDetail
  self.table_name = "supplier_cost_term_steps"

  belongs_to :supplier_cost_term, inverse_of: :steps
  monetize :unit_amount_minor_units, as: :unit_amount, with_model_currency: :term_currency

  validates :band_start_quantity, numericality: { only_integer: true, greater_than: 0 }
  validates :band_end_quantity, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :unit_amount_minor_units, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :band_end_after_start

  def term_currency
    supplier_cost_term&.currency
  end

  private

  def band_end_after_start
    return if band_start_quantity.blank? || band_end_quantity.blank? || band_end_quantity >= band_start_quantity

    errors.add(:band_end_quantity, "must be greater than or equal to the band start")
  end
end
