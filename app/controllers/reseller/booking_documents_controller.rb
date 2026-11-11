# R-04: the reseller issues its booking's confirmation (DOC-24).
class Reseller::BookingDocumentsController < ::BookingDocumentsController
  include ResellerBookingAccess

  private

  def require_booking_management! = require_permission!(:reseller_issue_confirmation)
end
