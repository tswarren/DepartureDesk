# Takes a traveler off a draft booking, with their occupancy and prices,
# re-holding what changed (step 6 plan, question 15).
class RemoveBookingTraveler < AgencyCommand
  include BookingCommandSupport

  def initialize(agency:, actor:, booking:, booking_traveler:)
    @agency = agency
    @actor = actor
    @booking = booking
    @booking_traveler = booking_traveler
  end

  def call
    ensure_actor!

    ActiveRecord::Base.transaction do
      booking = lock_booking!
      ensure_draft!(booking)
      record = booking.booking_travelers.find(@booking_traveler.id)
      affected = booking.choice_selections.select { |selection| selection.occupants.any? { |occupant| occupant.booking_traveler_id == record.id } }
      BookingPriceLine.where(booking_traveler_id: record.id).delete_all
      SelectionOccupant.where(booking_traveler_id: record.id).delete_all
      record.destroy!
      travelers = booking.booking_travelers.reload.to_a
      affected.each { |selection| position_occupants!(selection, travelers.select { |traveler| selection.occupants.reload.any? { |occupant| occupant.booking_traveler_id == traveler.id } }) }
      after_contents_change!(booking)
      audit_booking!(booking, "client_booking.traveler_removed", "booking_traveler_id" => record.id, "traveler_id" => record.traveler_id)
      Result.new(status: :removed, record:)
    end
  end
end
