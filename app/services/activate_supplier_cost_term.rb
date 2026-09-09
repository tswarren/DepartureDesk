class ActivateSupplierCostTerm < DepartureCommand
  def initialize(agency:, term:, lock_version: nil, actor: nil, actor_identifier: nil, privileged: false)
    @agency = agency
    @term = term
    @departure = term.departure
    @lock_version = lock_version
    assign_command_actors(actor:, actor_identifier:, privileged:)
  end

  def call
    ActiveRecord::Base.transaction do
      with_departure_locks(@agency, offices: [ @term.office ], departure: @departure, supplier_arrangements: [ @term.arrangement ], supplier_cost_terms: [ @term ]) { perform }
    end
  rescue ActiveRecord::StaleObjectError
    raise Error.new("This supplier cost term was updated by someone else.", code: :conflict)
  rescue ActiveRecord::RecordInvalid => error
    raise Error.new(error.record.errors.full_messages.to_sentence, code: :invalid)
  rescue ActiveRecord::RecordNotUnique
    raise Error.new("An active supplier cost term already exists for that economic item.", code: :conflict)
  end

  private

  def perform
    actor = actor_membership(@agency)
    ensure_office_access!(actor, @term.office)
    require_manager_or_administrator!(actor, @departure)
    ensure_departure_can_receive_supplier_planning!(@departure)
    ensure_fresh_lock!(@term, @lock_version)
    raise Error.new("Only draft supplier cost terms can be activated.", code: :invalid_state) unless @term.draft?
    SupplierCostTermEvaluation.evaluate(@term)

    @term.update!(status: "active", status_changed_at: Time.current, status_changed_by_membership: actor)
    audit!(agency: @agency, action: "supplier_cost_term.activated", subject: @term, details: { "supplier_cost_term_id" => @term.id, "basis" => @term.basis, "shape" => @term.shape }, **actor_audit_args)
    CommandResult.new(status: :accepted, departure: @departure, supplier_cost_term: @term)
  end
end
