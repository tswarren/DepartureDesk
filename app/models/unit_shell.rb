# One independently tracked, supplier-reservable unit, such as a cabin, room
# or excursion resource (INV-05, INV-16). Created only at confirmation
# (SUP-12). Its status is derived, never stored (INV-38).
class UnitShell < ApplicationRecord
  STATUS_LABELS = {
    "available" => "Available", "partly_allocated" => "Partly allocated", "fully_allocated" => "Fully allocated", "returned" => "Returned to supplier"
  }.freeze

  belongs_to :agency
  belongs_to :inventory_group
  has_many :capacity_events, dependent: :restrict_with_exception
  has_many :cost_line_shells, dependent: :restrict_with_exception
  has_many :inventory_allocations, dependent: :restrict_with_exception

  attr_readonly :agency_id, :inventory_group_id

  scope :ordered, -> { order(:position) }

  # Returned to supplier while its withdrawals outnumber its reinstatements,
  # recorded or scheduled. This is the supplier side only: a shell a client
  # holds still owes its deposit (step 6 plan, question 18).
  def returned_to_supplier?
    events = capacity_events.to_a
    events.count { |event| event.event_type == "withdrawn" } > events.count { |event| event.event_type == "reinstated" }
  end

  # Positions consumed now by Reserved allocations and holds not yet lapsed.
  def positions_used(at: Clock.current.now)
    inventory_allocations.select { |allocation| allocation.consuming?(at:) }.sum(&:quantity)
  end

  def positions_left(at: Clock.current.now) = [ positions - positions_used(at:), 0 ].max

  # INV-38, derived from allocations and supplier adjustments, never stored.
  def status(at: Clock.current.now)
    return "returned" if returned_to_supplier?

    used = positions_used(at:)
    return "available" if used.zero?

    used >= positions ? "fully_allocated" : "partly_allocated"
  end
end
