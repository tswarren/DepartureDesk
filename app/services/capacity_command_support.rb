# Rewritten for ADR 0018's spike amendment: no version lookups, and a short
# lock order (agency, Departure, arrangement, then the inventory group row
# last) that every command touching capacity follows. Events are
# append-only, replay must never go negative, and each event carries an
# idempotency key so a resubmitted form records nothing twice.
module CapacityCommandSupport
  include ArrangementCommandSupport

  private

  def lock_capacity_context!
    departure = lock_arrangement_context!
    arrangement = lock_arrangement!(departure)
    raise AgencyCommand::Error.new("Capacity changes need a confirmed arrangement.", code: :invalid_state) unless arrangement.confirmed?

    group = arrangement.inventory_groups.lock.find(@group.id)
    raise AgencyCommand::Error.new("#{group.label} holds no numeric capacity.", code: :invalid_state) unless group.numeric?

    [ departure, arrangement, group ]
  end

  def existing_event(key)
    key.present? ? @agency.capacity_events.find_by(idempotency_key: key) : nil
  end

  # Appends one event, refusing it if the replayed timeline would go below
  # zero, then refreshes the group's projection.
  def append_capacity_event!(departure:, arrangement:, group:, event_type:, quantity:, effective_on:, evidence_note: nil, shell: nil, corrects: nil, key: nil)
    recorded_at = Clock.current.now
    zone = @agency.default_timezone
    local_today = recorded_at.in_time_zone(zone).to_date
    applies_at = effective_on <= local_today ? recorded_at : AgencyLocalTime.end_of_date(effective_on, zone)
    existing = CapacityEvent.where(inventory_group_id: group.id).to_a
    sequence = existing.select { |prior| prior.effective_on == effective_on }.map(&:effective_sequence).max.to_i + 1

    event = CapacityEvent.new(
      inventory_group: group, agency: @agency, departure:, supplier_arrangement: arrangement, capacity_pool: group.capacity_pool, unit_shell: shell,
      event_type:, quantity:, effective_on:, effective_time_zone: zone, applies_at:, effective_sequence: sequence,
      recorded_at:, evidence_note: evidence_note.to_s.strip.presence, corrects_event: corrects, actor: @actor,
      idempotency_key: key.presence || SecureRandom.uuid
    )
    begin
      CapacityTimelineReplay.new(existing + [ event ]).call
    rescue CapacityTimelineReplay::NegativeQuantity
      raise AgencyCommand::Error.new("That would take #{group.label} below zero.", code: :invalid)
    end
    event.save!
    refresh_projection!(group)
    event
  end

  def refresh_projection!(group)
    projection = group.capacity_projection || group.create_capacity_projection!(agency: @agency, rebuilt_at: Clock.current.now)
    CapacityProjectionRefresher.call(group: group.reload, projection:)
  end

  def parse_effective_on(value)
    return Clock.current.today_in(@agency.default_timezone) if value.blank?

    value.is_a?(Date) ? value : Date.iso8601(value.to_s)
  rescue Date::Error
    raise AgencyCommand::Error.new("Enter a valid effective date.", code: :invalid)
  end

  def parse_quantity(value)
    quantity = Integer(value.to_s, exception: false)
    raise AgencyCommand::Error.new("Enter a whole number of 1 or more.", code: :invalid) unless quantity && quantity >= 1

    quantity
  end

  def next_shell_labels(group, count)
    start = group.unit_shells.maximum(:position).to_i
    (1..count).map { |offset| [ "#{group.label}-#{format("%02d", start + offset)}", start + offset ] }
  end

  def create_shells!(group, count)
    next_shell_labels(group, count).map do |label, position|
      group.unit_shells.create!(agency: @agency, label:, position:, positions: group.positions_per_unit)
    end
  end

  def audit_capacity!(arrangement, group, event)
    audit!(
      agency: @agency, action: "supplier_arrangement.capacity_changed", subject: arrangement, actor: @actor,
      details: { "inventory_group_id" => group.id, "capacity_event_id" => event.id, "event_type" => event.event_type,
                 "quantity" => event.quantity, "effective_on" => event.effective_on.iso8601, "unit_shell_id" => event.unit_shell_id }
    )
  end
end
