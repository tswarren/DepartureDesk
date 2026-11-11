# R-03: the staff action, on a booking the reseller's relationship owns.
class Reseller::BookingAcceptancesController < ::BookingAcceptancesController
  include ResellerBookingAccess
end
