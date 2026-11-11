# The booking screens (S-25, S-26): every staff user may view and manage
# bookings (ACC-30). Bookings are loaded through the agency, so another
# agency's id is not found. A refused action redirects back to the section
# of the workspace it came from, with its reason.
#
# The reseller's booking screens (R-03) reuse these controllers from the
# Reseller namespace through ResellerBookingAccess, which loads bookings
# through the reseller's scope instead (step 9 plan, question 8).
module BookingAccess
  extend ActiveSupport::Concern

  included do
    helper_method :booking_step_path, :booking_route, :booking_manager?
    before_action :require_booking_access!
    before_action :require_booking_management!, unless: -> { action_name.in?(%w[show index]) }
  end

  private

  def require_booking_access! = require_permission!(:view_bookings)

  def require_booking_management! = require_permission!(:manage_bookings)

  def require_directory_management! = require_permission!(:manage_client_directory)

  def booking_manager? = Current.agency_user.permitted?(:manage_bookings)

  def booking_scope = Current.agency.client_bookings

  def set_booking
    @booking = booking_scope.find(params[:client_booking_id] || params[:id])
  end

  # A booking route in the area serving the request: the staff route, or
  # the Reseller namespace's route of the same name.
  def booking_route(name, *args, **options)
    name = name.to_s.sub(/\A(new_|edit_)?/) { "#{$1}reseller_" } if reseller_area?
    public_send(:"#{name}_path", *args, **options)
  end

  # The workspace step that shows a section, opened at that section.
  def booking_step_path(booking, anchor = nil, step: nil)
    booking_route(:client_booking, booking, step: step || BookingProgress.step_for(anchor), anchor:)
  end

  def run_booking_command(anchor, notice, step: nil)
    yield
    redirect_to booking_step_path(@booking, anchor, step:), notice:
  rescue AgencyCommand::Error => error
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    redirect_to booking_step_path(@booking, anchor, step:), alert: error.message
  end
end
