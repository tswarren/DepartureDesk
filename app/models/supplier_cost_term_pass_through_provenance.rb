class SupplierCostTermPassThroughProvenance < SupplierCostTermDetail
  self.table_name = "supplier_cost_term_pass_through_provenances"

  belongs_to :supplier_cost_term, inverse_of: :pass_through_provenance
  monetize :supplier_amount_minor_units, as: :supplier_amount, with_model_currency: :term_currency

  normalizes :supplier_amount_reference, :provenance, with: ->(value) { value&.strip }

  validates :supplier_amount_minor_units, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :supplier_amount_reference, :provenance, presence: true

  def term_currency
    supplier_cost_term&.currency
  end
end
