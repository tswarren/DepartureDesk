class CreateSupplierReservation < DepartureCommand
  def initialize(agency:, arrangement:, name:, resources: [], operational_notes: nil, lock_version: nil, actor: nil, actor_identifier: nil, privileged: false)
    @agency = agency
    @arrangement = arrangement
    @departure = arrangement.departure
    @name = name
    @resources = Array(resources).compact
    @operational_notes = operational_notes
    @lock_version = lock_version
    assign_command_actors(actor:, actor_identifier:, privileged:)
  end

  def call
    ActiveRecord::Base.transaction do
      with_departure_locks(@agency, offices: [ @arrangement.office ], departure: @departure, supplier_arrangements: [ @arrangement ], supplier_resources: @resources) { perform }
    end
  rescue ActiveRecord::StaleObjectError
    raise Error.new("This supplier arrangement was updated by someone else.", code: :conflict)
  rescue ActiveRecord::RecordInvalid => error
    raise Error.new(error.record.errors.full_messages.to_sentence, code: :invalid)
  rescue ActiveRecord::RecordNotUnique
    raise Error.new("That resource is already linked to this reservation.", code: :conflict)
  end

  private

  def perform
    actor = actor_membership(@agency)
    ensure_office_access!(actor, @arrangement.office)
    ensure_departure_can_receive_supplier_planning!(@departure)
    ensure_fresh_lock!(@arrangement, @lock_version)
    raise Error.new("Reservations can only be added under nonterminal arrangements.", code: :invalid_state) unless @arrangement.nonterminal?
    @resources.each { |resource| ensure_resource_available!(resource) }

    reservation = @arrangement.supplier_reservations.create!(
      agency: @agency,
      office: @arrangement.office,
      departure: @departure,
      name: @name,
      status: "requested",
      operational_notes: @operational_notes,
      created_by_membership: actor,
      status_changed_at: Time.current,
      status_changed_by_membership: actor
    )
    @resources.each do |resource|
      reservation.supplier_reservation_resources.create!(agency: @agency, office: @arrangement.office, departure: @departure, arrangement: @arrangement, resource:, created_by_membership: actor)
    end
    audit!(agency: @agency, action: "supplier_reservation.created", subject: reservation, details: { "supplier_reservation_id" => reservation.id, "supplier_arrangement_id" => @arrangement.id, "resource_ids" => @resources.map(&:id) }, **actor_audit_args)
    CommandResult.new(status: :created, departure: @departure, supplier_reservation: reservation)
  end

  def ensure_resource_available!(resource)
    unless resource.arrangement_id == @arrangement.id && resource.active?
      raise Error.new("Choose active resources on this supplier arrangement.", code: :invalid)
    end
  end
end
