class ReferenceSequence < ApplicationRecord
  CLIENT_NAMESPACE = "client"
  SUPPLIER_NAMESPACE = "supplier"
  EXHAUSTED_AT = 1_000_000

  belongs_to :agency

  attr_readonly :agency_id, :namespace

  validates :namespace, inclusion: { in: [ CLIENT_NAMESPACE, SUPPLIER_NAMESPACE ] }
  validates :next_value, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: EXHAUSTED_AT }
end
