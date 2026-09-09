class SupplierCapacityCommand < DepartureCommand
  EVENT_TYPE = nil
  DELTAS = {}.freeze
  CAN_INITIALIZE_POSITION = false
  REQUIRES_MANAGER = false
  REQUIRES_ADMIN = false
  REQUIRES_APPROVAL = false
  REQUIRES_RESERVATION = false
  GUARANTEE_SIGN = 1

  def initialize(
    agency:,
    resource:,
    service_occurrence:,
    quantity:,
    reason:,
    idempotency_key:,
    effective_on: nil,
    reservation: nil,
    guaranteed_quantity: 0,
    supplier_approval_reference: nil,
    supplier_approval_received_at: nil,
    lock_version: nil,
    actor: nil,
    actor_identifier: nil,
    privileged: false
  )
    @agency = agency
    @resource = resource
    @service_occurrence = service_occurrence
    @departure = resource.departure
    @quantity = Integer(quantity)
    @reason = reason.to_s.strip
    @idempotency_key = idempotency_key.to_s.strip.downcase
    @effective_on = effective_on || OfficeDate.today(resource.office)
    @reservation = reservation
    @guaranteed_quantity = Integer(guaranteed_quantity || 0)
    @supplier_approval_reference = supplier_approval_reference.to_s.strip.presence
    @supplier_approval_received_at = supplier_approval_received_at
    @lock_version = lock_version
    assign_command_actors(actor:, actor_identifier:, privileged:)
  rescue ArgumentError, TypeError
    raise Error.new("Capacity quantities must be whole numbers.", code: :invalid)
  end

  def call
    validate_basic_inputs!
    ActiveRecord::Base.transaction do
      with_departure_locks(
        @agency,
        offices: [ @resource.office ],
        departure: @departure,
        supplier_arrangements: [ @resource.arrangement ],
        supplier_resources: [ @resource ],
        supplier_service_occurrences: [ @service_occurrence ],
        supplier_reservations: [ @reservation ]
      ) { perform }
    end
  rescue ActiveRecord::StaleObjectError
    raise Error.new("This supplier capacity position was updated by someone else.", code: :conflict)
  rescue ActiveRecord::RecordInvalid => error
    raise Error.new(error.record.errors.full_messages.to_sentence, code: :invalid)
  rescue ActiveRecord::RecordNotUnique
    replay_after_unique_violation
  end

  private

  def validate_basic_inputs!
    raise Error.new("Capacity quantity must be positive.", code: :invalid) unless @quantity.positive?
    raise Error.new("Guaranteed capacity quantity cannot be negative.", code: :invalid) if @guaranteed_quantity.negative?
    raise Error.new("A capacity reason is required.", code: :invalid) if @reason.blank?
    raise Error.new("A capacity idempotency key is required.", code: :invalid) unless uuid?(@idempotency_key)
    raise Error.new("A supplier reservation is required for capacity consumption.", code: :reservation_required) if self.class::REQUIRES_RESERVATION && @reservation.blank?
    if self.class::REQUIRES_APPROVAL && (@supplier_approval_reference.blank? || @supplier_approval_received_at.blank?)
      raise Error.new("Supplier-approved provenance is required.", code: :supplier_approval_required)
    end
  end

  def perform
    existing = @agency.supplier_capacity_events.find_by(idempotency_key: @idempotency_key)
    return replay_existing!(existing) if existing

    actor = capacity_actor_membership
    ensure_office_access!(actor, @resource.office) if actor
    ensure_tenant_actor!(@agency) if self.class::REQUIRES_ADMIN
    require_manager_or_administrator!(actor, @departure) if actor && self.class::REQUIRES_MANAGER
    ensure_departure_can_receive_supplier_planning!(@departure)
    ensure_fresh_lock!(@resource, @lock_version)
    ensure_scope!
    ensure_resource_active!
    ensure_reservation_context!

    position = load_or_initialize_position!
    position.lock!
    position.reload
    event = append_event!(position, actor)
    CommandResult.new(status: :accepted, departure: @departure, supplier_capacity_position: position, supplier_capacity_event: event)
  end

  def capacity_actor_membership
    return nil if @privileged

    actor_membership(@agency)
  end

  def ensure_scope!
    expected = [ @agency.id, @resource.office_id, @departure.id, @resource.arrangement_id, @resource.id ]
    if [ @service_occurrence.agency_id, @service_occurrence.office_id, @service_occurrence.departure_id, @service_occurrence.arrangement_id, @service_occurrence.resource_id ] != expected
      raise Error.new("That supplier service occurrence is not part of this resource.", code: :invalid)
    end
    return if @resource.capacity_unit == @service_occurrence.resource.capacity_unit

    raise Error.new("Capacity unit must match the supplier resource.", code: :invalid)
  end

  def ensure_resource_active!
    raise Error.new("Capacity can only change on active supplier resources.", code: :invalid_state) unless @resource.active?
  end

  def ensure_reservation_context!
    return unless @reservation

    if [ @reservation.agency_id, @reservation.office_id, @reservation.departure_id, @reservation.arrangement_id ] != [ @agency.id, @resource.office_id, @departure.id, @resource.arrangement_id ]
      raise Error.new("That supplier reservation is not part of this arrangement.", code: :invalid)
    end
    unless @reservation.supplier_reservation_resources.where(resource_id: @resource.id).exists?
      raise Error.new("That supplier reservation does not use this resource.", code: :invalid)
    end
  end

  def load_or_initialize_position!
    position = SupplierCapacityPosition.find_by(resource: @resource, service_occurrence: @service_occurrence, capacity_unit: @resource.capacity_unit)
    return position if position

    if self.class::CAN_INITIALIZE_POSITION && !events_exist_for_position?
      return SupplierCapacityPosition.create_or_find_by!(
        resource: @resource,
        service_occurrence: @service_occurrence,
        capacity_unit: @resource.capacity_unit
      ) do |new_position|
        new_position.agency = @agency
        new_position.office = @resource.office
        new_position.departure = @departure
        new_position.arrangement = @resource.arrangement
      end
    end

    raise Error.new("Capacity position is missing; reconcile it before mutating capacity.", code: :capacity_position_missing)
  end

  def events_exist_for_position?
    SupplierCapacityEvent.exists?(resource: @resource, service_occurrence: @service_occurrence, capacity_unit: @resource.capacity_unit)
  end

  def append_event!(position, actor)
    deltas = event_deltas
    proposed = SupplierCapacityPosition::BUCKETS.index_with { |bucket| position.public_send(bucket) + deltas.fetch(bucket, 0) }
    if proposed.values.any?(&:negative?) || proposed["consumed"] > proposed["agency_held"]
      raise Error.new("Capacity transition would make a stored bucket negative.", code: :invalid_transition)
    end

    event = position.supplier_capacity_events.create!(
      agency: @agency,
      office: @resource.office,
      departure: @departure,
      arrangement: @resource.arrangement,
      resource: @resource,
      service_occurrence: @service_occurrence,
      reservation: @reservation,
      capacity_unit: @resource.capacity_unit,
      event_type: self.class::EVENT_TYPE,
      quantity: @quantity,
      agency_held_delta: deltas.fetch("agency_held", 0),
      pending_request_delta: deltas.fetch("pending_request", 0),
      guaranteed_delta: deltas.fetch("guaranteed", 0),
      consumed_delta: deltas.fetch("consumed", 0),
      released_current_delta: deltas.fetch("released_current", 0),
      commanded_at: Time.current,
      effective_on: @effective_on,
      actor_kind: actor ? "membership" : "system",
      actor_membership: actor,
      actor_identifier: actor ? nil : @actor_identifier,
      reason: @reason,
      idempotency_key: @idempotency_key,
      supplier_approval_reference: @supplier_approval_reference,
      supplier_approval_received_at: @supplier_approval_received_at,
      **event_extra_attributes
    )
    position.update!(proposed)
    event
  end

  def event_extra_attributes
    {}
  end

  def event_deltas
    self.class::DELTAS.transform_values { |multiplier| multiplier * @quantity }.merge(guaranteed_delta)
  end

  def guaranteed_delta
    return {} if @guaranteed_quantity.zero?

    { "guaranteed" => self.class::GUARANTEE_SIGN * @guaranteed_quantity }
  end

  def replay_existing!(event)
    unless same_event_material?(event)
      raise Error.new("That idempotency key was already used for a different capacity command.", code: :idempotency_conflict)
    end

    CommandResult.new(status: :accepted, departure: @departure, supplier_capacity_position: event.supplier_capacity_position, supplier_capacity_event: event)
  end

  def replay_after_unique_violation
    event = @agency.supplier_capacity_events.find_by(idempotency_key: @idempotency_key)
    return replay_existing!(event) if event

    raise Error.new("That capacity command could not be applied.", code: :conflict)
  end

  def same_event_material?(event)
    deltas = event_deltas
    event.event_type == self.class::EVENT_TYPE &&
      event.resource_id == @resource.id &&
      event.service_occurrence_id == @service_occurrence.id &&
      event.capacity_unit == @resource.capacity_unit &&
      event.quantity == @quantity &&
      event.reservation_id == @reservation&.id &&
      event.effective_on.to_s == @effective_on.to_s &&
      SupplierCapacityPosition::BUCKETS.all? { |bucket| event.public_send("#{bucket}_delta") == deltas.fetch(bucket, 0) }
  end

  def uuid?(value)
    value.match?(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i)
  end
end
