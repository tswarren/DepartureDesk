# Links a booking's selection to a shell, positions in a shell, or a
# quantity of a pool (INV-17). Held, Reserved or Released (INV-18), moving
# only forward; Held and Reserved consume capacity, a Held one only until
# its expiry (D-88). A replacement after an edit names the allocation it
# replaces and keeps its expiry and extension (step 6 plan, questions 15
# and 20).
class InventoryAllocation < ApplicationRecord
  STATES = %w[held reserved released].freeze

  belongs_to :agency
  belongs_to :client_booking, inverse_of: :inventory_allocations
  belongs_to :choice_selection
  belongs_to :inventory_group
  belongs_to :unit_shell, optional: true
  belongs_to :replaces, class_name: "InventoryAllocation", foreign_key: :replaces_allocation_id, optional: true
  belongs_to :created_by, class_name: "AgencyUser"

  enum :state, STATES.index_by(&:itself), validate: true, prefix: :state

  attr_readonly :agency_id, :client_booking_id, :choice_selection_id, :inventory_group_id, :unit_shell_id, :quantity, :held_at, :replaces_allocation_id

  def consuming?(at: Clock.current.now)
    state_reserved? || (state_held? && hold_expires_at > at)
  end

  def lapsed?(at: Clock.current.now) = state_held? && hold_expires_at <= at
end
