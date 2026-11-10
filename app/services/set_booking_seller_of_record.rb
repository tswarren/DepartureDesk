# Records a booking's seller of record: the agency or an authorized reseller
# (FIN-05, seller of record only; step 9 plan question 6). It is separate
# from the owner and never follows a reassignment. It changes only while the
# booking is a draft: seller commission is outside the charter, so it is
# fixed once the booking is confirmed.
class SetBookingSellerOfRecord < AgencyCommand
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
      unless booking.status_draft?
        raise Error.new("The seller of record is fixed once a booking is #{booking.status_label.downcase}.", code: :invalid_state)
      end
      reseller = @reseller && @agency.resellers.lock.find(@reseller.id)
      raise Error.new("#{reseller.name} is #{reseller.status_label.downcase}, so it can't be a seller of record.", code: :invalid_state) if reseller && !reseller.active?
      return Result.new(status: :noop, record: booking) if booking.seller_reseller_id == reseller&.id

      from = booking.seller_reseller_id
      booking.update!(seller_kind: reseller ? "reseller" : "agency", seller_reseller: reseller)
      audit_booking!(booking, "client_booking.seller_of_record_set", "from_reseller_id" => from, "to_reseller_id" => reseller&.id)
      Result.new(status: :updated, record: booking)
    end
  rescue ActiveRecord::RecordInvalid => error
    raise Error.new(error.record.errors.full_messages.to_sentence, code: :invalid)
  end
end
