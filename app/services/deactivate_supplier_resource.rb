class DeactivateSupplierResource < DepartureCommand
  def initialize(agency:, resource:, reason:, lock_version: nil, actor: nil, actor_identifier: nil, privileged: false)
    @agency = agency
    @resource = resource
    @departure = resource.departure
    @reason = reason.to_s.strip
    @lock_version = lock_version
    assign_command_actors(actor:, actor_identifier:, privileged:)
  end

  def call
    raise Error.new("A deactivation reason is required.", code: :invalid) if @reason.blank?
    links = @resource.supplier_reservation_resources.includes(:reservation).select { |link| link.reservation&.nonterminal? }
    positions = @resource.supplier_capacity_positions.to_a
    ActiveRecord::Base.transaction do
      with_departure_locks(@agency, offices: [ @resource.office ], departure: @departure, supplier_resources: [ @resource ], supplier_reservations: links.map(&:reservation), supplier_capacity_positions: positions) { perform }
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
    ensure_fresh_lock!(@resource, @lock_version)
    return CommandResult.new(status: :accepted, departure: @departure, supplier_resource: @resource) if @resource.inactive?

    if @resource.supplier_reservations.nonterminal.exists?
      raise Error.new("Resolve nonterminal supplier reservations before deactivating this resource.", code: :dependency)
    end
    if @resource.supplier_capacity_positions.any? { |position| actionable_capacity?(position) }
      raise Error.new("Release, restore, or reconcile active capacity before deactivating this resource.", code: :dependency)
    end

    @resource.update!(status: "inactive", status_reason: @reason, status_changed_at: Time.current, status_changed_by_membership: actor)
    audit!(agency: @agency, action: "supplier_resource.deactivated", subject: @resource, details: { "supplier_resource_id" => @resource.id, "reason" => @reason }, **actor_audit_args)
    CommandResult.new(status: :accepted, departure: @departure, supplier_resource: @resource)
  end

  def actionable_capacity?(position)
    position.agency_held.positive? ||
      position.pending_request.positive? ||
      position.guaranteed.positive? ||
      position.consumed.positive? ||
      position.released_current.positive?
  end
end
