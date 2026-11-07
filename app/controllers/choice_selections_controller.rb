# Choices on a draft booking, with each unit's occupants or each add-on's
# participants (BKG-14 to BKG-16).
class ChoiceSelectionsController < ApplicationController
  include BookingAccess

  before_action :set_booking

  def create
    run_booking_command(anchor, "Choice saved.") do
      SaveChoiceSelection.new(agency: Current.agency, actor: Current.agency_user, booking: @booking, attributes: selection_params).call
    end
  end

  def update
    selection = @booking.choice_selections.find(params[:id])
    run_booking_command(anchor, "Choice updated.") do
      SaveChoiceSelection.new(agency: Current.agency, actor: Current.agency_user, booking: @booking, selection:,
        attributes: selection_params, lock_version: params.dig(:choice_selection, :lock_version)).call
    end
  end

  def destroy
    selection = @booking.choice_selections.find(params[:id])
    run_booking_command(anchor, "Choice removed.") do
      RemoveChoiceSelection.new(agency: Current.agency, actor: Current.agency_user, booking: @booking, selection:).call
    end
  end

  private

  def anchor = params[:choice_id].present? ? "choice-#{params[:choice_id]}" : "choices"

  def selection_params
    params.fetch(:choice_selection, {}).permit(:offering_option_id, occupant_ids: []).to_h
  end
end
