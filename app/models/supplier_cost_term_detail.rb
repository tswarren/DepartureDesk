class SupplierCostTermDetail < ApplicationRecord
  self.abstract_class = true

  belongs_to :agency
  belongs_to :supplier_cost_term, inverse_of: false

  validate :same_agency

  private

  def same_agency
    return if supplier_cost_term.blank? || agency_id.blank? || supplier_cost_term.agency_id == agency_id

    errors.add(:supplier_cost_term, "must belong to the same agency")
  end
end
