# Client money screens (S-28, S-29): every staff user sees them (CMN-19);
# recording, applying and reversing need Financial records. The trip is
# loaded through the agency, so another agency's id is not found.
module ClientMoneyAccess
  extend ActiveSupport::Concern

  included do
    before_action -> { require_permission!(:view_client_money) }
    before_action -> { require_permission!(:manage_client_money) }, unless: -> { action_name == "show" }
  end

  private

  def set_trip
    @trip = Current.agency.client_trips.find(params[:client_trip_id])
  end

  def money_redirect(notice: nil, alert: nil)
    redirect_to client_trip_path(@trip, anchor: "money"), notice:, alert:
  end
end
