# R-03: the staff action, on a booking the reseller's relationship owns.
class Reseller::ChoiceSelectionsController < ::ChoiceSelectionsController
  include ResellerBookingAccess
end
