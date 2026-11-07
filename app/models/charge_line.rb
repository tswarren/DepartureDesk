# One line of a client charge (CMN-01, CMN-02): its type, the traveler it
# relates to, the traveler type, occupancy position and chosen option
# accepted (BKG-25), the amount, its creditor and expected route. Never
# edited after creation (CMN-03).
class ChargeLine < ApplicationRecord
  TYPES = %w[traveler_price add_on].freeze

  belongs_to :agency
  belongs_to :client_charge, inverse_of: :lines
  belongs_to :choice_selection, optional: true
  belongs_to :booking_traveler, optional: true
  belongs_to :traveler_type, optional: true

  before_update { raise ActiveRecord::ReadOnlyRecord }
  before_destroy { raise ActiveRecord::ReadOnlyRecord }
end
