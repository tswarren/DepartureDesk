# Returns a Ready to sell Departure to Draft (DEP-06). The reference, team,
# decision and every other field stay. The note is optional; the spec's
# guard is the permission only. Withdrawing published offers (DEP-08) is
# added with publishing in step 9 (D-90).
class ReturnDepartureToDraft < AgencyCommand
  include DepartureCommandSupport

  REASON_LIMIT = 500

  def initialize(agency:, actor:, departure:, reason:, lock_version:)
    @agency = agency
    @actor = actor
    @departure = departure
    @reason = reason
    @lock_version = lock_version
  end

  def call
    ensure_departure_actor!(:manage_departures)

    ActiveRecord::Base.transaction do
      lock_authorized_agency!(:manage_departures)
      departure = lock_departure!
      return Result.new(status: :noop, record: departure) if departure.draft?
      if departure.departed?
        raise Error.new("A departed departure cannot return to draft.", code: :invalid_state)
      end

      ensure_current_lock_version!(departure)
      reason = normalized_reason
      departure.update!(sales_status: "draft")
      audit!(
        agency: @agency,
        action: "departure.returned_to_draft",
        subject: departure,
        actor: @actor,
        details: {
          "departure_id" => departure.id,
          "departure_reference" => departure.departure_reference,
          "note" => reason
        }
      )
      Result.new(status: :updated, record: departure)
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  end

  private

  def normalized_reason
    reason = @reason.to_s.strip.presence
    return if reason.nil?
    if reason.length > REASON_LIMIT
      raise Error.new("Reason must be #{REASON_LIMIT} characters or fewer.", code: :invalid)
    end

    reason
  end
end
