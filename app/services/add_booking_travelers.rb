# Adds several of the client's travelers to a draft booking at once, each
# with the traveler type staff choose for them (CLT-13, BKG-21): age is
# shown beside each but never chooses the type. One transaction, through
# SaveBookingTraveler for each, so a refusal adds none.
class AddBookingTravelers < AgencyCommand
  include BookingCommandSupport
  allow_reseller_actor

  def initialize(agency:, actor:, booking:, rows:)
    @agency = agency
    @actor = actor
    @booking = booking
    @rows = Array(rows).map { |row| row.to_h.stringify_keys.slice("traveler_id", "traveler_type_id") }.select { |row| row["traveler_id"].present? }
  end

  def call
    ensure_actor!
    raise Error.new("Tick at least one traveler to add.", code: :invalid) if @rows.empty?

    ActiveRecord::Base.transaction do
      records = @rows.map do |row|
        SaveBookingTraveler.new(agency: @agency, actor: @actor, booking: @booking, attributes: row.compact_blank).call.record
      end
      Result.new(status: :created, record: records)
    end
  end
end
