# R-03: the staff action, on a booking the reseller's relationship owns.
class Reseller::BookingAcceptanceEvidenceController < ::BookingAcceptanceEvidenceController
  include ResellerBookingAccess
end
