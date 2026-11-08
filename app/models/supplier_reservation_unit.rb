# One booking unit a supplier reservation covers: a per-unit selection,
# such as the Nov 2 Harbor Double room, or a per-traveler selection with
# its participants. A unit has one open reservation at a time (step 7
# plan, question 2).
class SupplierReservationUnit < ApplicationRecord
  belongs_to :agency
  belongs_to :supplier_reservation, inverse_of: :units
  belongs_to :choice_selection

  attr_readonly :agency_id, :supplier_reservation_id, :choice_selection_id
end
