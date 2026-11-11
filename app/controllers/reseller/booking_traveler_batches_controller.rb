# R-03: the staff action, on a booking the reseller's relationship owns.
class Reseller::BookingTravelerBatchesController < ::BookingTravelerBatchesController
  include ResellerBookingAccess
end
