# Moves a traveler one place up or down a draft booking's order, which sets
# guest order in each unit (CLT-13). The neighbor takes its place, unit
# positions follow, and prices and holds are refreshed in the same
# transaction (step 6 plan, questions 14 and 15).
class MoveBookingTraveler < AgencyCommand
  include BookingCommandSupport
  allow_reseller_actor

  DIRECTIONS = %w[up down].freeze

  def initialize(agency:, actor:, booking:, booking_traveler:, direction:)
    @agency = agency
    @actor = actor
    @booking = booking
    @booking_traveler = booking_traveler
    @direction = direction.to_s
  end

  def call
    ensure_actor!
    raise Error.new("Choose up or down.", code: :invalid) unless @direction.in?(DIRECTIONS)

    ActiveRecord::Base.transaction do
      booking = lock_booking!
      ensure_draft!(booking)
      ordered = booking.booking_travelers.lock.order(:position, :created_at).to_a
      index = ordered.index { |row| row.id == @booking_traveler.id } or raise Error.new("That traveler is not on this booking.", code: :not_found)
      other_index = @direction == "up" ? index - 1 : index + 1
      return Result.new(status: :noop, record: ordered[index]) if other_index.negative? || other_index >= ordered.size

      ordered[index], ordered[other_index] = ordered[other_index], ordered[index]
      ordered.each_with_index { |row, position| row.update!(position: position + 1) if row.position != position + 1 }
      reposition_occupants!(booking)
      after_contents_change!(booking)
      audit_booking!(booking, "client_booking.traveler_updated",
        "booking_traveler_id" => @booking_traveler.id, "traveler_id" => @booking_traveler.traveler_id, "changed" => [ "position" ])
      Result.new(status: :updated, record: ordered[other_index])
    end
  end
end
