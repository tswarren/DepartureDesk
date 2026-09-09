class VoidSupplierCostTerm < DepartureCommand
  def initialize(agency:, term:, reason:, lock_version: nil, actor: nil, actor_identifier: nil, privileged: false)
    @agency = agency
    @term = term
    @departure = term.departure
    @reason = reason.to_s.strip
    @lock_version = lock_version
    assign_command_actors(actor:, actor_identifier:, privileged:)
  end

  def call
    raise Error.new("A void reason is required.", code: :invalid) if @reason.blank?
    ActiveRecord::Base.transaction do
      with_departure_locks(@agency, offices: [ @term.office ], departure: @departure, supplier_arrangements: [ @term.arrangement ], supplier_cost_terms: [ @term ]) { perform }
    end
  rescue ActiveRecord::StaleObjectError
    raise Error.new("This supplier cost term was updated by someone else.", code: :conflict)
  rescue ActiveRecord::RecordInvalid => error
    raise Error.new(error.record.errors.full_messages.to_sentence, code: :invalid)
  end

  private

  def perform
    actor = actor_membership(@agency)
    ensure_office_access!(actor, @term.office)
    require_manager_or_administrator!(actor, @departure) if @term.active?
    ensure_fresh_lock!(@term, @lock_version)
    return CommandResult.new(status: :accepted, departure: @departure, supplier_cost_term: @term) if @term.void?
    raise Error.new("Only draft or active supplier cost terms can be voided.", code: :invalid_state) unless @term.draft? || @term.active?

    @term.update!(status: "void", status_reason: @reason, status_changed_at: Time.current, status_changed_by_membership: actor)
    audit!(agency: @agency, action: "supplier_cost_term.voided", subject: @term, details: { "supplier_cost_term_id" => @term.id, "reason" => @reason }, **actor_audit_args)
    CommandResult.new(status: :accepted, departure: @departure, supplier_cost_term: @term)
  end
end
