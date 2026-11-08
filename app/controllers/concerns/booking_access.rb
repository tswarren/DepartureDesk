# The booking screens (S-25, S-26): every staff user may view and manage
# bookings (ACC-30). Bookings are loaded through the agency, so another
# agency's id is not found. A refused action redirects back to the section
# of the workspace it came from, with its reason.
module BookingAccess
  extend ActiveSupport::Concern

  included do
    helper_method :booking_step_path
    before_action -> { require_permission!(:view_bookings) }
    before_action -> { require_permission!(:manage_bookings) }, unless: -> { action_name.in?(%w[show index]) }
  end

  private

  def set_booking
    @booking = Current.agency.client_bookings.find(params[:client_booking_id] || params[:id])
  end

  # The workspace step that shows a section, opened at that section.
  def booking_step_path(booking, anchor = nil, step: nil)
    client_booking_path(booking, step: step || BookingProgress.step_for(anchor), anchor:)
  end

  def run_booking_command(anchor, notice, step: nil)
    yield
    redirect_to booking_step_path(@booking, anchor, step:), notice:
  rescue AgencyCommand::Error => error
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    redirect_to booking_step_path(@booking, anchor, step:), alert: error.message
  end
end
