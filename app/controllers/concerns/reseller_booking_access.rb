# The reseller's booking screens (R-03): the staff booking controllers,
# serving only the bookings the reseller's relationship owns (ACC-14,
# ACC-15). Each command checks the reseller again, so a refused action is
# refused by the server whatever the screen shows.
module ResellerBookingAccess
  extend ActiveSupport::Concern

  include ResellerArea

  private

  def require_booking_access! = require_permission!(:reseller_view_offers)

  def require_booking_management! = require_permission!(:reseller_manage_bookings)

  # CLT-25: a reseller adds new travelers to its own bookings; the command decides.
  def require_directory_management! = nil

  def booking_manager? = Current.agency_user.permitted?(:reseller_manage_bookings)

  def booking_scope = reseller_scope.bookings
end
