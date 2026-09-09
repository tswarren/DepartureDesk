class ActivateSupplierArrangement < DepartureCommand
  def initialize(agency:, arrangement:, lock_version: nil, actor: nil, actor_identifier: nil, privileged: false)
    @agency = agency
    @arrangement = arrangement
    @departure = arrangement.departure
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
    require_manager_or_administrator!(actor, @departure)
    ensure_departure_can_receive_supplier_planning!(@departure)
    ensure_fresh_lock!(@arrangement, @lock_version)
    raise Error.new("Only draft supplier arrangements can be activated.", code: :invalid_state) unless @arrangement.draft?

    @arrangement.update!(status: "active", status_changed_at: Time.current, status_changed_by_membership: actor)
    audit!(agency: @agency, action: "supplier_arrangement.activated", subject: @arrangement, details: { "supplier_arrangement_id" => @arrangement.id }, **actor_audit_args)
    CommandResult.new(status: :accepted, departure: @departure, supplier_arrangement: @arrangement)
  end
end
