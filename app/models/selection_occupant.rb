# A booking traveler in a per-unit selection, with a position in that unit,
# or a participant in a per-traveler selection, without one. A traveler
# whose type the group's capacity rule says uses no capacity has no
# position (INV-39).
class SelectionOccupant < ApplicationRecord
  belongs_to :agency
  belongs_to :choice_selection, inverse_of: :occupants
  belongs_to :booking_traveler

  attr_readonly :agency_id, :choice_selection_id, :booking_traveler_id
end
