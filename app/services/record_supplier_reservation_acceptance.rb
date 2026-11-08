# Records that the supplier accepted a request (INV-34, INV-35): its
# reference, kept beside the agency's own (REF-09), the date it answered
# and a note. Acceptance changes the reservation only: never the client's
# accepted price, the booking or its allocations.
class RecordSupplierReservationAcceptance < AgencyCommand
  include SupplierReservationSupport

  def initialize(agency:, actor:, reservation:, attributes:, lock_version: nil)
    @agency = agency
    @actor = actor
    @reservation = reservation
    @attributes = attributes.to_h.stringify_keys
    @lock_version = lock_version
  end

  def call
    ensure_reservation_actor!
    reference = @attributes["supplier_reference"].to_s.squish.presence or raise Error.new("Supplier reference is required.", code: :invalid)
    responded_on = parse_date

    ActiveRecord::Base.transaction do
      lock_reservation_context!(@reservation.client_booking, @reservation.supplier_arrangement)
      reservation = @agency.supplier_reservations.lock.find(@reservation.id)
      raise Error.new(STALE_MESSAGE, code: :conflict) if @lock_version.present? && reservation.lock_version != @lock_version.to_i
      raise Error.new("Only a requested reservation can be accepted; this one is #{reservation.status_label.downcase}.", code: :invalid_state) unless reservation.status_requested?

      reservation.update!(status: "confirmed", supplier_reference: reference, responded_on:, response_note: @attributes["response_note"],
        responded_by: @actor, responded_at: Clock.current.now)
      record_event!(reservation, "confirmed", responded_on)
      audit!(agency: @agency, action: "supplier_reservation.confirmed", subject: reservation, actor: @actor,
        details: { "supplier_reservation_id" => reservation.id, "supplier_reference" => reference, "responded_on" => responded_on.iso8601 })
      Result.new(status: :updated, record: reservation)
    end
  rescue ActiveRecord::RecordInvalid => error
    raise Error.new(error.record.errors.full_messages.to_sentence, code: :invalid)
  end

  private

  def parse_date
    value = @attributes["responded_on"].presence
    return agency_today if value.nil?

    date = Date.iso8601(value.to_s)
    raise Error.new("Response date can't be in the future.", code: :invalid) if date > agency_today

    date
  rescue Date::Error
    raise Error.new("Response date must be a date, such as 2027-01-20.", code: :invalid)
  end
end
