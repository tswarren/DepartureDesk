class UpdateSupplierResource < DepartureCommand
  EDITABLE = %w[name resource_kind description].freeze

  def initialize(agency:, resource:, name:, resource_kind:, description: nil, lock_version: nil, actor: nil, actor_identifier: nil, privileged: false)
    @agency = agency
    @resource = resource
    @departure = resource.departure
    @name = name
    @resource_kind = resource_kind
    @description = description
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
  end

  private

  def perform
    actor = actor_membership(@agency)
    ensure_office_access!(actor, @resource.office)
    ensure_departure_can_receive_supplier_planning!(@departure)
    ensure_fresh_lock!(@resource, @lock_version)
    raise Error.new("Inactive resources cannot be updated.", code: :invalid_state) unless @resource.active?

    before = snapshot
    @resource.assign_attributes(name: @name, resource_kind: @resource_kind, description: @description)
    return CommandResult.new(status: :accepted, departure: @departure, supplier_resource: @resource) unless @resource.changed?

    @resource.save!
    after = snapshot
    changed = EDITABLE.select { |field| before[field] != after[field] }
    audit!(agency: @agency, action: "supplier_resource.updated", subject: @resource, details: { "supplier_resource_id" => @resource.id, "changed_fields" => changed, "before" => before.slice(*changed), "after" => after.slice(*changed) }, **actor_audit_args)
    CommandResult.new(status: :accepted, departure: @departure, supplier_resource: @resource)
  end

  def snapshot
    { "name" => @resource.name, "resource_kind" => @resource.resource_kind, "description" => @resource.description }
  end
end
