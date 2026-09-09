class ReconcileCapacityPosition < DepartureCommand
  def initialize(agency:, position:, reason:, actor: nil, actor_identifier: nil, privileged: false)
    @agency = agency
    @position = position
    @resource = position.resource
    @service_occurrence = position.service_occurrence
    @departure = position.departure
    @reason = reason.to_s.strip
    assign_command_actors(actor:, actor_identifier:, privileged:)
  end

  def call
    raise Error.new("A reconciliation reason is required.", code: :invalid) if @reason.blank?
    ActiveRecord::Base.transaction do
      with_departure_locks(
        @agency,
        offices: [ @position.office ],
        departure: @departure,
        supplier_arrangements: [ @position.arrangement ],
        supplier_resources: [ @resource ],
        supplier_service_occurrences: [ @service_occurrence ],
        supplier_capacity_positions: [ @position ],
        require_administrator: true
      ) { perform }
    end
  rescue ActiveRecord::RecordInvalid => error
    raise Error.new(error.record.errors.full_messages.to_sentence, code: :invalid)
  end

  private

  def perform
    ensure_scope!
    events = @position.supplier_capacity_events.order(:commanded_at, :id).to_a
    rebuilt = rebuild(events)
    before = @position.attributes.slice(*SupplierCapacityPosition::BUCKETS)
    if before == rebuilt
      return CommandResult.new(status: :accepted, departure: @departure, supplier_capacity_position: @position)
    end

    @position.update!(rebuilt)
    audit!(
      agency: @agency,
      action: "supplier_capacity_position.reconciled",
      subject: @position,
      details: {
        "supplier_capacity_position_id" => @position.id,
        "resource_id" => @position.resource_id,
        "service_occurrence_id" => @position.service_occurrence_id,
        "capacity_unit" => @position.capacity_unit,
        "before" => before,
        "after" => rebuilt,
        "reason" => @reason
      },
      **actor_audit_args
    )
    CommandResult.new(status: :accepted, departure: @departure, supplier_capacity_position: @position)
  end

  def ensure_scope!
    return if [ @resource.agency_id, @resource.office_id, @resource.departure_id, @resource.arrangement_id ] == [ @agency.id, @position.office_id, @departure.id, @position.arrangement_id ] &&
      [ @service_occurrence.agency_id, @service_occurrence.office_id, @service_occurrence.departure_id, @service_occurrence.arrangement_id, @service_occurrence.resource_id ] == [ @agency.id, @position.office_id, @departure.id, @position.arrangement_id, @resource.id ]

    raise Error.new("That capacity position is not part of this supplier resource occurrence.", code: :invalid)
  end

  def rebuild(events)
    buckets = SupplierCapacityPosition::BUCKETS.index_with(0)
    events.each do |event|
      SupplierCapacityPosition::BUCKETS.each do |bucket|
        buckets[bucket] += event.public_send("#{bucket}_delta")
      end
      if buckets.values.any?(&:negative?) || buckets["consumed"] > buckets["agency_held"]
        raise Error.new("Capacity events cannot rebuild to a valid position.", code: :invalid_projection)
      end
    end
    buckets
  end
end
