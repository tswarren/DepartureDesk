# Adds supplier capacity to a confirmed group: more shells, or more pool
# places (INV-26). A future date takes effect at 11:59 p.m. agency time on
# that date (D-88).
class IncreaseCapacity < AgencyCommand
  include CapacityCommandSupport

  def initialize(agency:, actor:, departure:, arrangement:, group:, quantity:, effective_on: nil, evidence_note: nil, idempotency_key: nil)
    @agency = agency
    @actor = actor
    @departure = departure
    @arrangement = arrangement
    @group = group
    @quantity = quantity
    @effective_on = effective_on
    @evidence_note = evidence_note
    @key = idempotency_key
  end

  def call
    ensure_departure_actor!(:manage_arrangements)
    quantity = parse_quantity(@quantity)
    effective_on = parse_effective_on(@effective_on)

    ActiveRecord::Base.transaction do
      departure, arrangement, group = lock_capacity_context!
      if (existing = existing_event(@key))
        return Result.new(status: :noop, record: existing)
      end

      create_shells!(group, quantity) if group.represented_as_unit_shells?
      event = append_capacity_event!(departure:, arrangement:, group:, event_type: "increased", quantity:, effective_on:, evidence_note: @evidence_note, key: @key)
      audit_capacity!(arrangement, group, event)
      Result.new(status: :created, record: event)
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  end
end
