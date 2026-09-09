class CreateSupplierServiceOccurrence < DepartureCommand
  def initialize(agency:, resource:, occurrence_kind:, service_date: nil, segment_type: nil, segment_identifier: nil, label: nil, lock_version: nil, actor: nil, actor_identifier: nil, privileged: false)
    @agency = agency
    @resource = resource
    @departure = resource.departure
    @occurrence_kind = occurrence_kind
    @service_date = service_date
    @segment_type = segment_type
    @segment_identifier = segment_identifier
    @label = label
    @lock_version = lock_version
    assign_command_actors(actor:, actor_identifier:, privileged:)
  end

  def call
    ActiveRecord::Base.transaction do
      with_departure_locks(@agency, offices: [ @resource.office ], departure: @departure, supplier_resources: [ @resource ]) { perform }
    end
  rescue ActiveRecord::StaleObjectError
    raise Error.new("This supplier resource was updated by someone else.", code: :conflict)
  rescue ActiveRecord::RecordInvalid => error
    raise Error.new(error.record.errors.full_messages.to_sentence, code: :invalid)
  rescue ActiveRecord::RecordNotUnique
    raise Error.new("That supplier service occurrence already exists.", code: :conflict)
  end

  private

  def perform
    actor = actor_membership(@agency)
    ensure_office_access!(actor, @resource.office)
    ensure_departure_can_receive_supplier_planning!(@departure)
    ensure_fresh_lock!(@resource, @lock_version)
    raise Error.new("Occurrences can only be added under active resources.", code: :invalid_state) unless @resource.active?

    occurrence = @resource.supplier_service_occurrences.create!(
      agency: @agency,
      office: @resource.office,
      departure: @departure,
      arrangement: @resource.arrangement,
      occurrence_kind: @occurrence_kind,
      service_date: @service_date,
      segment_type: @segment_type,
      segment_identifier: @segment_identifier,
      label: @label,
      created_by_membership: actor
    )
    audit!(agency: @agency, action: "supplier_service_occurrence.created", subject: occurrence, details: { "supplier_service_occurrence_id" => occurrence.id, "supplier_resource_id" => @resource.id, "occurrence_kind" => occurrence.occurrence_kind }, **actor_audit_args)
    CommandResult.new(status: :created, departure: @departure, supplier_service_occurrence: occurrence)
  end
end
