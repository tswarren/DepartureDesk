class SupplierCostTermMinimumGuaranteeDetail < SupplierCostTermDetail
  self.table_name = "supplier_cost_term_minimum_guarantee_details"

  belongs_to :supplier_cost_term, inverse_of: :minimum_guarantee_detail
  monetize :unit_amount_minor_units, as: :unit_amount, with_model_currency: :term_currency, allow_nil: true
  monetize :minimum_amount_minor_units, as: :minimum_amount, with_model_currency: :term_currency, allow_nil: true

  validates :minimum_quantity, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :unit_amount_minor_units, :minimum_amount_minor_units,
    numericality: { only_integer: true, greater_than_or_equal_to: 0 },
    allow_nil: true
  validate :minimum_present

  def term_currency
    supplier_cost_term&.currency
  end

  private

  def minimum_present
    return if minimum_amount_minor_units.present? || (minimum_quantity.present? && unit_amount_minor_units.present?)

    errors.add(:base, "minimum amount or quantity and unit amount is required")
  end
end
