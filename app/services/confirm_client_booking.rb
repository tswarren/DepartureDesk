# Confirms a booking (BKG-45). Build step 6b checks what confirmation
# needs and refuses, listing each missing item with where to fix it (D16);
# acceptance and the confirmation effects arrive in build step 6c.
class ConfirmClientBooking < AgencyCommand
  include BookingCommandSupport

  class Blocked < AgencyCommand::Error
    attr_reader :blockers

    def initialize(blockers)
      @blockers = blockers
      super("This booking can't be confirmed yet.", code: :invalid_state)
    end
  end

  def initialize(agency:, actor:, booking:)
    @agency = agency
    @actor = actor
    @booking = booking
  end

  def call
    ensure_actor!

    ActiveRecord::Base.transaction do
      booking = lock_booking!
      ensure_draft!(booking)
      blockers = BookingConfirmationCheck.new(booking).blockers
      raise Blocked.new(blockers) if blockers.any?

      raise Error.new("Confirmation arrives in build step 6c.", code: :invalid_state)
    end
  end
end
