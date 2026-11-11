# R-03: the staff action, on a booking the reseller's relationship owns.
class Reseller::BookingDiscardsController < ::BookingDiscardsController
  include ResellerBookingAccess
end
