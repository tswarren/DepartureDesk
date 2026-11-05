# Records an operating decision on a Departure (DEP-16, DEP-19, DEP-20).
# Slice 1 accepts Proceed only (charter scope); Postpone and Cancel, with
# their effects, come with the cancellation and postponement workflows.
class RecordDepartureDecision < AgencyCommand
  include DepartureCommandSupport

  SLICE_1_DECISIONS = %w[proceed].freeze

  def initialize(agency:, actor:, departure:, decision:, note: nil, lock_version:)
    @agency = agency
    @actor = actor
    @departure = departure
    @decision = decision.to_s
    @note = note
    @lock_version = lock_version
  end

  def call
    ensure_departure_actor!(:manage_departures)
    raise Error.new("Only Proceed can be recorded yet.", code: :invalid) unless @decision.in?(SLICE_1_DECISIONS)

    ActiveRecord::Base.transaction do
      lock_authorized_agency!(:manage_departures)
      departure = lock_departure!
      ensure_current_lock_version!(departure)
      raise Error.new("A departed departure's decision cannot change.", code: :invalid_state) if departure.departed?

      decision = departure.decisions.create!(
        agency: @agency, decision: @decision, note: @note, decided_by: @actor, decided_at: Time.current
      )
      previous = departure.operating_decision
      departure.update!(operating_decision: @decision)
      audit!(
        agency: @agency,
        action: "departure.decision_recorded",
        subject: departure,
        actor: @actor,
        details: {
          "departure_id" => departure.id,
          "departure_decision_id" => decision.id,
          "decision" => @decision,
          "previous_decision" => previous,
          "note" => decision.note
        }
      )
      Result.new(status: :created, record: decision)
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  end
end
