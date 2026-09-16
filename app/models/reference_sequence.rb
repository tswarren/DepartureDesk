class ReferenceSequence < ApplicationRecord
  CLIENT_NAMESPACE = "client"
  SUPPLIER_NAMESPACE = "supplier"
  DEPARTURE_NAMESPACE = "departure"
  EXHAUSTED_AT = 1_000_000
  NAMESPACES = [ CLIENT_NAMESPACE, SUPPLIER_NAMESPACE, DEPARTURE_NAMESPACE ].freeze

  belongs_to :agency

  attr_readonly :agency_id, :namespace

  validates :namespace, inclusion: { in: NAMESPACES }
  validates :next_value, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: EXHAUSTED_AT }
end
