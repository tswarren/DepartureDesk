# R-03: the staff action, on a booking the reseller's relationship owns.
class Reseller::BookingTravelerMovesController < ::BookingTravelerMovesController
  include ResellerBookingAccess
end
