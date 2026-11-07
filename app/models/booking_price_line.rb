# A booking's proposed client price for one traveler on one selection, or
# for a per-trip selection (step 6 plan, question 14). Proposed from the
# offering's prices and kept: a change to an offering price touches no
# booking (BKG-23). Confirmation in build step 6c makes the charge lines
# from these.
class BookingPriceLine < ApplicationRecord
  belongs_to :agency
  belongs_to :client_booking, inverse_of: :price_lines
  belongs_to :choice_selection
  belongs_to :booking_traveler, optional: true
  belongs_to :offering_price, optional: true
  belongs_to :traveler_type, optional: true

  attr_readonly :agency_id, :client_booking_id, :choice_selection_id
end
