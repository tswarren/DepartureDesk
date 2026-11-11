# Assigns a booking to an authorized reseller or to agency ownership
# (ACC-18; step 9 plan question 6). Assignment changes who handles the
# booking and so what a reseller can see (ACC-14); it never changes the
# seller of record (FIN-05). ACC-18's notices are Slice 2 notifications.
class AssignClientBooking < AgencyCommand
  include BookingCommandSupport

  def initialize(agency:, actor:, booking:, reseller:, lock_version: nil)
    @agency = agency
    @actor = actor
    @booking = booking
    @reseller = reseller
    @lock_version = lock_version
  end

  def call
    ensure_directory_actor!(@actor, @agency, :assign_bookings)
    ensure_active_agency!(@agency)

    ActiveRecord::Base.transaction do
      booking = lock_booking!
      ensure_version!(booking)
      if booking.status_discarded? || booking.status_cancelled?
        raise Error.new("A #{booking.status_label.downcase} booking can't be reassigned.", code: :invalid_state)
      end
      reseller = @reseller && @agency.resellers.lock.find(@reseller.id)
      raise Error.new("#{reseller.name} is #{reseller.status_label.downcase}, so it can't take bookings.", code: :invalid_state) if reseller && !reseller.active?
      return Result.new(status: :noop, record: booking) if booking.owner_reseller_id == reseller&.id

      from = booking.owner_reseller_id
      booking.update!(owner_kind: reseller ? "reseller" : "agency", owner_reseller: reseller)
      audit_booking!(booking, "client_booking.assigned", "from_reseller_id" => from, "to_reseller_id" => reseller&.id)
      Result.new(status: :updated, record: booking)
    end
  rescue ActiveRecord::RecordInvalid => error
    raise Error.new(error.record.errors.full_messages.to_sentence, code: :invalid)
  end
end
