# Extra nights as a range on a draft booking (BKG-14).
class ChoiceSelectionRangesController < ApplicationController
  include BookingAccess

  before_action :set_booking

  def create
    run_booking_command(params[:choice_id].present? ? "choice-#{params[:choice_id]}" : "choices", "Nights added.") do
      AddChoiceSelectionRange.new(agency: Current.agency, actor: Current.agency_user, booking: @booking,
        attributes: params.fetch(:selection_range, {}).permit(:choice_id, :mode, :kind, :from, :through, occupant_ids: [], rooms: [ :kind, { occupant_ids: [] } ]).to_h).call
    end
  end
end
