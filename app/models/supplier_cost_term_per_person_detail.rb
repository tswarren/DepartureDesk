class SupplierCostTermPerPersonDetail < SupplierCostTermDetail
  self.table_name = "supplier_cost_term_per_person_details"

  belongs_to :supplier_cost_term, inverse_of: :per_person_detail
  monetize :unit_amount_minor_units, as: :unit_amount, with_model_currency: :term_currency

  validates :unit_amount_minor_units, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :planning_person_quantity, :guaranteed_person_quantity,
    numericality: { only_integer: true, greater_than: 0 },
    allow_nil: true
  validate :quantity_present

  def person_quantity
    guaranteed_person_quantity || planning_person_quantity
  end

  def term_currency
    supplier_cost_term&.currency
  end

  private

  def quantity_present
    return if planning_person_quantity.present? || guaranteed_person_quantity.present?

    errors.add(:base, "planning or guaranteed person quantity is required")
  end
end
