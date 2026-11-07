# Corrects a pool's capacity up or down, naming the event it corrects
# (ADR 0018: corrections reference, never edit). Agency-initiated, so a
# downward correction may use only unallocated capacity (INV-26): it is
# refused if supply would fall below the allocations consuming capacity at
# the instant it applies or after. A hold that lapses first doesn't block it.
class CorrectCapacity < AgencyCommand
  include CapacityCommandSupport

  DIRECTIONS = { "up" => "corrected_up", "down" => "corrected_down" }.freeze

  def initialize(agency:, actor:, departure:, arrangement:, group:, direction:, quantity:, corrects_event_id:, effective_on: nil, evidence_note: nil, idempotency_key: nil)
    @agency = agency
    @actor = actor
    @departure = departure
    @arrangement = arrangement
    @group = group
    @direction = direction.to_s
    @quantity = quantity
    @corrects_event_id = corrects_event_id
    @effective_on = effective_on
    @evidence_note = evidence_note
    @key = idempotency_key
  end

  def call
    ensure_departure_actor!(:manage_arrangements)
    event_type = DIRECTIONS.fetch(@direction) { raise Error.new("Choose up or down.", code: :invalid) }
    quantity = parse_quantity(@quantity)
    effective_on = parse_effective_on(@effective_on)

    ActiveRecord::Base.transaction do
      departure, arrangement, group = lock_capacity_context!
      if (existing = existing_event(@key))
        return Result.new(status: :noop, record: existing)
      end
      raise Error.new("Corrections apply to capacity pools; add or return shells instead.", code: :invalid_state) unless group.represented_as_capacity_pool?

      corrects = group.capacity_events.find_by(id: parse_optional_uuid(@corrects_event_id, "Event"))
      raise Error.new("Choose the event this corrects.", code: :invalid) if corrects.nil?

      event = append_capacity_event!(departure:, arrangement:, group:, event_type:, quantity:, effective_on:, evidence_note: @evidence_note, corrects:, key: @key,
        guard_allocations: event_type == "corrected_down")
      audit_capacity!(arrangement, group, event)
      Result.new(status: :created, record: event)
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  end
end
