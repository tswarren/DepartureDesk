# Records the supplier taking back capacity: pool places, or one shell
# returned to the supplier (INV-26). A supplier-driven reduction is recorded
# even below active allocations; GroupCapacity then derives the capacity
# conflict, which blocks new holds and confirmation (INV-19, INV-27).
class RecordSupplierRelease < AgencyCommand
  include CapacityCommandSupport

  def initialize(agency:, actor:, departure:, arrangement:, group:, quantity: nil, unit_shell_id: nil, effective_on: nil, evidence_note: nil, idempotency_key: nil)
    @agency = agency
    @actor = actor
    @departure = departure
    @arrangement = arrangement
    @group = group
    @quantity = quantity
    @unit_shell_id = unit_shell_id
    @effective_on = effective_on
    @evidence_note = evidence_note
    @key = idempotency_key
  end

  def call
    ensure_departure_actor!(:manage_arrangements)
    effective_on = parse_effective_on(@effective_on)

    ActiveRecord::Base.transaction do
      departure, arrangement, group = lock_capacity_context!
      if (existing = existing_event(@key))
        return Result.new(status: :noop, record: existing)
      end

      shell = nil
      quantity = if group.represented_as_unit_shells?
        shell = group.unit_shells.find_by(id: parse_optional_uuid(@unit_shell_id, "Shell"))
        raise Error.new("Choose the shell the supplier is taking back.", code: :invalid) if shell.nil?
        raise Error.new("#{shell.label} is already returned to the supplier.", code: :invalid_state) if shell.status == "returned"

        1
      else
        parse_quantity(@quantity)
      end
      event = append_capacity_event!(departure:, arrangement:, group:, event_type: "withdrawn", quantity:, effective_on:, evidence_note: @evidence_note, shell:, key: @key)
      audit_capacity!(arrangement, group, event)
      Result.new(status: :created, record: event)
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  end
end
