class CancelSupplierArrangement < DepartureCommand
  def initialize(agency:, arrangement:, reason:, lock_version: nil, actor: nil, actor_identifier: nil, privileged: false)
    @agency = agency
    @arrangement = arrangement
    @departure = arrangement.departure
    @reason = reason.to_s.strip
    @lock_version = lock_version
    assign_command_actors(actor:, actor_identifier:, privileged:)
  end

  def call
    raise Error.new("A cancellation reason is required.", code: :invalid) if @reason.blank?
    children = @arrangement.child_arrangements.nonterminal.to_a
    reservations = @arrangement.supplier_reservations.nonterminal.to_a
    ActiveRecord::Base.transaction do
      with_departure_locks(@agency, offices: [ @arrangement.office ], departure: @departure, supplier_arrangements: [ @arrangement, *children ], supplier_reservations: reservations) { perform }
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
    ensure_fresh_lock!(@arrangement, @lock_version)
    return CommandResult.new(status: :accepted, departure: @departure, supplier_arrangement: @arrangement) if @arrangement.cancelled?
    raise Error.new("Only draft or active supplier arrangements can be cancelled.", code: :invalid_state) unless @arrangement.nonterminal?

    if @arrangement.child_arrangements.nonterminal.exists? || @arrangement.supplier_reservations.nonterminal.exists?
      raise Error.new("Cancel, decline, or reparent child supplier planning before cancelling this arrangement.", code: :dependency)
    end

    @arrangement.update!(status: "cancelled", status_reason: @reason, status_changed_at: Time.current, status_changed_by_membership: actor)
    audit!(agency: @agency, action: "supplier_arrangement.cancelled", subject: @arrangement, details: { "supplier_arrangement_id" => @arrangement.id, "reason" => @reason }, **actor_audit_args)
    CommandResult.new(status: :accepted, departure: @departure, supplier_arrangement: @arrangement)
  end
end
