# One dated change to a group's supplier capacity (INV-26). Append-only:
# corrections reference the event they correct (ADR 0018).
class CapacityEvent < ApplicationRecord
  TYPES = CapacityTimelineReplay::DIRECTIONS.keys.freeze
  LABELS = {
    "established" => "Opening", "increased" => "Increase", "released" => "Agency release", "reinstated" => "Reinstated",
    "withdrawn" => "Supplier release", "corrected_up" => "Correction up", "corrected_down" => "Correction down"
  }.freeze

  belongs_to :agency
  belongs_to :departure
  belongs_to :supplier_arrangement
  belongs_to :inventory_group
  belongs_to :capacity_pool, optional: true
  belongs_to :unit_shell, optional: true
  belongs_to :corrects_event, class_name: "CapacityEvent", optional: true
  belongs_to :actor, class_name: "AgencyUser"

  validates :event_type, inclusion: { in: TYPES }
  validates :quantity, numericality: { only_integer: true, greater_than: 0 }

  before_update { raise ActiveRecord::ReadOnlyRecord, "capacity events are append-only" }
  before_destroy { raise ActiveRecord::ReadOnlyRecord, "capacity events are append-only" }

  def signed_quantity
    CapacityTimelineReplay::DIRECTIONS.fetch(event_type).sign * quantity
  end
end
