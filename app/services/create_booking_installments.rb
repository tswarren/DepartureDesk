# Gives a confirmed booking with no installments the ones its locked terms
# version proposes, dated from its confirmation (CMN-08, CMN-12; D-94 (2),
# step 8 plan question 2). For bookings confirmed before build step 8;
# idempotent, so running it again creates nothing.
class CreateBookingInstallments < AgencyCommand
  include BookingCommandSupport

  def initialize(agency:, booking:, actor_identifier: "bookings.create_missing_installments")
    @agency = agency
    @booking = booking
    @actor_identifier = actor_identifier
  end

  def call
    ActiveRecord::Base.transaction do
      booking = lock_booking!
      charge = booking.client_charge
      return Result.new(status: :noop, record: booking) unless booking.status_confirmed? && charge && charge.installments.none?

      rows = InstallmentSchedule.new(booking:, terms_version: booking.client_terms_version, total_minor_units: charge.total_minor_units).rows
      now = Clock.current.now
      installments = create_installments!(charge, rows, booking.confirmed_at.in_time_zone(@agency.default_timezone).to_date, now)
      audit!(agency: @agency, action: "client_booking.installments_created", subject: booking, actor_identifier: @actor_identifier,
        details: { "client_booking_id" => booking.id, "installment_ids" => installments.map(&:id) })
      Result.new(status: :created, record: installments)
    end
  end
end
