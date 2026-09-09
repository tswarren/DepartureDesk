class SupplierCostTermPercentageBaseRef < SupplierCostTermDetail
  self.table_name = "supplier_cost_term_percentage_base_refs"

  belongs_to :supplier_cost_term, inverse_of: :percentage_base_ref
  monetize :base_amount_minor_units, as: :base_amount, with_model_currency: :term_currency, allow_nil: true

  normalizes :base_economic_item_key, :base_reference, with: ->(value) { value&.strip.presence }

  validates :rate_basis_points, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :base_amount_minor_units, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :base_reference, presence: true
  validate :base_source_present

  def term_currency
    supplier_cost_term&.currency
  end

  private

  def base_source_present
    return if base_amount_minor_units.present? || base_economic_item_id.present? || base_economic_item_key.present?

    errors.add(:base, "base amount or economic item reference is required")
  end
end
