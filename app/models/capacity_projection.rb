class CapacityProjection < ApplicationRecord
  belongs_to :agency
  belongs_to :departure
  belongs_to :supplier_arrangement
  belongs_to :arrangement_item
  belongs_to :service_occurrence
  belongs_to :supplier_resource
  belongs_to :capacity_pool
  belongs_to :last_event, class_name: "CapacityEvent", optional: true
  belongs_to :next_event, class_name: "CapacityEvent", optional: true

  attr_readonly :agency_id, :departure_id, :supplier_arrangement_id,
    :arrangement_item_id, :service_occurrence_id, :supplier_resource_id,
    :capacity_pool_id

  validates :current_supplier_capacity,
    numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :rebuilt_at, presence: true
  validates :last_effective_sequence,
    numericality: { only_integer: true, greater_than: 0 },
    allow_nil: true
end
