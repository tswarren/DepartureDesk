class CreateSupplierResource < DepartureCommand
  def initialize(agency:, arrangement:, name:, resource_kind:, capacity_unit:, description: nil, lock_version: nil, actor: nil, actor_identifier: nil, privileged: false)
    @agency = agency
    @arrangement = arrangement
    @departure = arrangement.departure
    @name = name
    @resource_kind = resource_kind
    @capacity_unit = capacity_unit
    @description = description
    @lock_version = lock_version
    assign_command_actors(actor:, actor_identifier:, privileged:)
  end

  def call
    ActiveRecord::Base.transaction do
      with_departure_locks(@agency, offices: [ @arrangement.office ], departure: @departure, supplier_arrangements: [ @arrangement ]) { perform }
    end
  rescue ActiveRecord::StaleObjectError
    raise Error.new("This supplier arrangement was updated by someone else.", code: :conflict)
  rescue ActiveRecord::RecordInvalid => error
    raise Error.new(error.record.errors.full_messages.to_sentence, code: :invalid)
  end

  private

  def perform
    actor = actor_membership(@agency)
    ensure_office_access!(actor, @arrangement.office)
    ensure_departure_can_receive_supplier_planning!(@departure)
    ensure_fresh_lock!(@arrangement, @lock_version)
    raise Error.new("Resources can only be added under nonterminal arrangements.", code: :invalid_state) unless @arrangement.nonterminal?

    resource = @arrangement.supplier_resources.create!(
      agency: @agency,
      office: @arrangement.office,
      departure: @departure,
      name: @name,
      resource_kind: @resource_kind,
      capacity_unit: @capacity_unit,
      description: @description,
      status: "active",
      created_by_membership: actor,
      status_changed_at: Time.current,
      status_changed_by_membership: actor
    )
    audit!(agency: @agency, action: "supplier_resource.created", subject: resource, details: { "supplier_resource_id" => resource.id, "supplier_arrangement_id" => @arrangement.id, "capacity_unit" => resource.capacity_unit }, **actor_audit_args)
    CommandResult.new(status: :created, departure: @departure, supplier_resource: resource)
  end
end
