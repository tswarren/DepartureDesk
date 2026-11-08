# Adds or edits a traveler on a draft booking (CLT-13, CLT-15): a traveler
# profile or a placeholder, with the traveler type staff choose (BKG-21).
# A change that affects prices or space re-proposes the prices and re-holds
# in the same transaction (step 6 plan, questions 14 and 15).
class SaveBookingTraveler < AgencyCommand
  include BookingCommandSupport

  FIELDS = %w[traveler_id placeholder_label traveler_type_id position].freeze

  def initialize(agency:, actor:, booking:, attributes:, booking_traveler: nil, lock_version: nil)
    @agency = agency
    @actor = actor
    @booking = booking
    @booking_traveler = booking_traveler
    @attributes = clean(attributes, FIELDS)
    @lock_version = lock_version
  end

  def call
    ensure_actor!

    ActiveRecord::Base.transaction do
      booking = lock_booking!
      ensure_draft!(booking)
      record = @booking_traveler ? booking.booking_travelers.find(@booking_traveler.id).tap { |row| ensure_version!(row) } : booking.booking_travelers.new(agency: @agency)
      creating = record.new_record?
      record.assign_attributes(resolved_attributes(booking, record))
      changed = record.changed - %w[lock_version updated_at]
      return Result.new(status: :noop, record:) if !creating && changed.empty?

      record.save!
      reposition_occupants!(booking) if (changed & %w[traveler_type_id position]).any?
      after_contents_change!(booking)
      audit_booking!(booking, creating ? "client_booking.traveler_added" : "client_booking.traveler_updated",
        "booking_traveler_id" => record.id, "traveler_id" => record.traveler_id, "changed" => changed.sort)
      Result.new(status: creating ? :created : :updated, record:)
    end
  rescue ActiveRecord::RecordInvalid => error
    raise Error.new(error.record.errors.full_messages.to_sentence, code: :invalid)
  end

  private

  def resolved_attributes(booking, record)
    result = {}
    if @attributes.key?("traveler_id") || @attributes.key?("placeholder_label")
      traveler = @attributes["traveler_id"] && (@agency.travelers.find_by(id: @attributes["traveler_id"]) || raise(Error.new("Traveler must be one of this agency's.", code: :invalid)))
      result["traveler_id"] = traveler&.id
      result["placeholder_label"] = traveler ? nil : @attributes["placeholder_label"]
    end
    if @attributes.key?("traveler_type_id")
      type = @attributes["traveler_type_id"] && (@agency.traveler_types.find_by(id: @attributes["traveler_type_id"]) || raise(Error.new("Traveler type must be one of this agency's.", code: :invalid)))
      raise Error.new("Traveler type #{type.name} is inactive.", code: :invalid) if type&.inactive? && type.id != record.traveler_type_id
      result["traveler_type_id"] = type&.id
    end
    position = Integer(@attributes["position"].to_s, exception: false)
    result["position"] = position if position&.positive?
    result["position"] ||= booking.booking_travelers.maximum(:position).to_i + 1 if record.new_record?
    result
  end
end
