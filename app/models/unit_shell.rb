# One independently tracked, supplier-reservable unit, such as a cabin, room
# or excursion resource (INV-05, INV-16). Created only at confirmation
# (SUP-12). Its status is derived, never stored (INV-38).
class UnitShell < ApplicationRecord
  STATUS_LABELS = { "available" => "Available", "returned" => "Returned to supplier" }.freeze

  belongs_to :agency
  belongs_to :inventory_group
  has_many :capacity_events, dependent: :restrict_with_exception

  attr_readonly :agency_id, :inventory_group_id

  scope :ordered, -> { order(:position) }

  # Available or Returned to supplier until step 6 adds allocations
  # (Partly and Fully allocated). A shell is returned while its withdrawals
  # outnumber its reinstatements.
  def status
    events = capacity_events.to_a
    returned = events.count { |event| event.event_type == "withdrawn" } > events.count { |event| event.event_type == "reinstated" }
    returned ? "returned" : "available"
  end
end
