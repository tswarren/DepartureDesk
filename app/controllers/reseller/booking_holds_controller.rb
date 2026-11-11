# R-03: the staff action, on a booking the reseller's relationship owns.
class Reseller::BookingHoldsController < ::BookingHoldsController
  include ResellerBookingAccess
end
