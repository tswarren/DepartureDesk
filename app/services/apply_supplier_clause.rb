class ApplySupplierClause < DepartureCommand
  CAPACITY_EVENTS = {
    "release" => "release",
    "reduction" => "reduction",
    "expiration" => "expiration",
    "guarantee_adjustment" => "correction"
  }.freeze

  COMMITMENT_STATUSES = {
    "release" => "released",
    "satisfy" => "satisfied",
    "cancel" => "cancelled"
  }.freeze

  def initialize(agency:, clause:, reason:, idempotency_key:, effective_on: nil, lock_version: nil, actor: nil, actor_identifier: nil, privileged: false)
    @agency = agency
    @clause = clause
    @departure = clause.departure
    @reason = reason.to_s.strip
    @idempotency_key = idempotency_key.to_s.strip.downcase
    @effective_on = effective_on || OfficeDate.today(clause.office)
    @lock_version = lock_version
    assign_command_actors(actor:, actor_identifier:, privileged:)
  end

  def preview
    validate_basic_inputs!
    actor = actor_membership(@agency)
    ensure_office_access!(actor, @clause.office)
    require_manager_or_administrator!(actor, @departure)
    ensure_clause_scope!
    build_preview
  rescue ArgumentError => error
    raise Error.new(error.message, code: :invalid)
  end

  def call
    validate_basic_inputs!
    ActiveRecord::Base.transaction do
      with_departure_locks(
        @agency,
        offices: [ @clause.office ],
        departure: @departure,
        supplier_arrangements: [ @clause.arrangement ],
        supplier_clauses: [ @clause ],
        supplier_resources: [ @clause.resource ],
        supplier_service_occurrences: [ @clause.service_occurrence ],
        supplier_cost_terms: [ @clause.governing_term ],
        supplier_commitments: [ @clause.affected_commitment ]
      ) { perform }
    end
  rescue ActiveRecord::StaleObjectError
    raise Error.new("This supplier clause was updated by someone else.", code: :conflict)
  rescue ActiveRecord::RecordInvalid => error
    raise Error.new(error.record.errors.full_messages.to_sentence, code: :invalid)
  rescue ActiveRecord::RecordNotUnique
    raise Error.new("That clause application was already recorded.", code: :conflict)
  end

  private

  def validate_basic_inputs!
    raise Error.new("A clause application reason is required.", code: :invalid) if @reason.blank?
    raise Error.new("A clause application idempotency key is required.", code: :invalid) unless uuid?(@idempotency_key)
  end

  def perform
    actor = actor_membership(@agency)
    ensure_office_access!(actor, @clause.office)
    require_manager_or_administrator!(actor, @departure)
    ensure_departure_can_receive_supplier_planning!(@departure)
    ensure_fresh_lock!(@clause, @lock_version)
    raise Error.new("Clauses can only be applied under nonterminal arrangements.", code: :invalid_state) unless @clause.arrangement.nonterminal?
    raise Error.new("That clause application key was already used.", code: :idempotency_conflict) if @agency.supplier_capacity_events.exists?(idempotency_key: @idempotency_key)

    ensure_clause_scope!
    preview = build_preview
    capacity_event = append_capacity_event!(preview.capacity_consequence, actor) if preview.capacity?
    commitment = apply_commitment_consequence!(preview.commitment_consequence, actor) if preview.commitment?

    audit!(
      agency: @agency,
      action: "supplier_clause.applied",
      subject: @clause,
      details: {
        "supplier_clause_id" => @clause.id,
        "reason" => @reason,
        "supplier_capacity_event_ids" => [ capacity_event&.id ].compact,
        "supplier_commitment_ids" => [ commitment&.id ].compact,
        "commitment_action" => preview.commitment_consequence&.action
      },
      **actor_audit_args
    )
    CommandResult.new(
      status: :accepted,
      departure: @departure,
      supplier_clause: @clause,
      supplier_clause_preview: preview,
      supplier_capacity_event: capacity_event,
      supplier_commitment: commitment
    )
  end

  def ensure_clause_scope!
    return if [ @clause.agency_id, @clause.departure_id ] == [ @agency.id, @departure.id ]

    raise Error.new("That supplier clause is not part of this agency.", code: :invalid)
  end

  def build_preview
    SupplierClausePreview.new(
      clause: @clause,
      capacity_consequence: capacity_consequence,
      commitment_consequence: commitment_consequence
    )
  end

  def capacity_consequence
    return if @clause.capacity_action == "none"

    position = SupplierCapacityPosition.find_by(
      resource: @clause.resource,
      service_occurrence: @clause.service_occurrence,
      capacity_unit: @clause.resource.capacity_unit
    )
    raise Error.new("Capacity position is missing; reconcile it before applying this clause.", code: :capacity_position_missing) unless position
    raise Error.new("Clause capacity consequence must have a positive event quantity.", code: :invalid) unless event_quantity.positive?

    deltas = capacity_deltas
    proposed = SupplierCapacityPosition::BUCKETS.index_with { |bucket| position.public_send(bucket) + deltas.fetch(bucket, 0) }
    if proposed.values.any?(&:negative?) || proposed["consumed"] > proposed["agency_held"]
      raise Error.new("Clause application would make a stored capacity bucket negative.", code: :invalid_transition)
    end

    SupplierClausePreview::CapacityConsequence.new(
      event_type: CAPACITY_EVENTS.fetch(@clause.capacity_action),
      resource_id: @clause.resource_id,
      service_occurrence_id: @clause.service_occurrence_id,
      capacity_unit: @clause.resource.capacity_unit,
      quantity: event_quantity,
      deltas:
    )
  end

  def capacity_deltas
    quantity = @clause.capacity_quantity.to_i
    guaranteed = @clause.guaranteed_quantity.to_i

    case @clause.capacity_action
    when "release"
      { "agency_held" => -quantity, "released_current" => quantity, "guaranteed" => -guaranteed }
    when "reduction"
      { "agency_held" => -quantity, "guaranteed" => -guaranteed }
    when "expiration"
      { "agency_held" => -quantity, "released_current" => quantity, "guaranteed" => -guaranteed }
    when "guarantee_adjustment"
      { "guaranteed" => guaranteed }
    else
      {}
    end
  end

  def event_quantity
    return @clause.guaranteed_quantity.to_i if @clause.capacity_action == "guarantee_adjustment"

    @clause.capacity_quantity.to_i
  end

  def commitment_consequence
    case @clause.commitment_action
    when "none"
      nil
    when "open"
      raise Error.new("Commitment clauses require an active governing cost term.", code: :invalid_state) unless @clause.governing_term&.active?

      evaluation = SupplierCostTermEvaluation.evaluate(@clause.governing_term)
      SupplierClausePreview::CommitmentConsequence.new(
        action: "open",
        commitment_id: nil,
        governing_term_id: @clause.governing_term_id,
        amount_minor_units: evaluation.amount_minor_units,
        currency: evaluation.currency
      )
    else
      commitment = @clause.affected_commitment
      raise Error.new("Only open supplier commitments can be changed by a clause.", code: :invalid_state) unless commitment&.open?

      SupplierClausePreview::CommitmentConsequence.new(
        action: @clause.commitment_action,
        commitment_id: commitment.id,
        governing_term_id: commitment.governing_term_id,
        amount_minor_units: commitment.valuation_amount_minor_units,
        currency: commitment.currency
      )
    end
  end

  def append_capacity_event!(consequence, actor)
    position = SupplierCapacityPosition.find_by!(
      resource_id: consequence.resource_id,
      service_occurrence_id: consequence.service_occurrence_id,
      capacity_unit: consequence.capacity_unit
    )
    position.lock!
    position.reload

    proposed = SupplierCapacityPosition::BUCKETS.index_with { |bucket| position.public_send(bucket) + consequence.deltas.fetch(bucket, 0) }
    if proposed.values.any?(&:negative?) || proposed["consumed"] > proposed["agency_held"]
      raise Error.new("Clause application would make a stored capacity bucket negative.", code: :invalid_transition)
    end

    event = position.supplier_capacity_events.create!(
      agency: @agency,
      office: @clause.office,
      departure: @departure,
      arrangement: @clause.arrangement,
      resource: @clause.resource,
      service_occurrence: @clause.service_occurrence,
      capacity_unit: consequence.capacity_unit,
      event_type: consequence.event_type,
      quantity: consequence.quantity,
      agency_held_delta: consequence.deltas.fetch("agency_held", 0),
      pending_request_delta: consequence.deltas.fetch("pending_request", 0),
      guaranteed_delta: consequence.deltas.fetch("guaranteed", 0),
      consumed_delta: consequence.deltas.fetch("consumed", 0),
      released_current_delta: consequence.deltas.fetch("released_current", 0),
      commanded_at: Time.current,
      effective_on: @effective_on,
      actor_kind: "membership",
      actor_membership: actor,
      reason: @reason,
      idempotency_key: @idempotency_key
    )
    position.update!(proposed)
    event
  end

  def apply_commitment_consequence!(consequence, actor)
    case consequence.action
    when "open"
      term = @clause.governing_term
      term.arrangement.supplier_commitments.create!(
        agency: @agency,
        office: term.office,
        departure: @departure,
        reservation: term.reservation,
        resource: term.resource,
        service_occurrence: term.service_occurrence,
        governing_term: term,
        economic_item_id: term.economic_item_id,
        economic_item_key: term.economic_item_key,
        cost_category: term.cost_category,
        quantity_basis: term.quantity_basis,
        quantity_unit: term.quantity_unit,
        currency: consequence.currency,
        valuation_amount_minor_units: consequence.amount_minor_units,
        valuation_details: { "explanation" => "opened by supplier clause", "supplier_clause_id" => @clause.id },
        governing_term_snapshot: term.display_snapshot,
        status: "open",
        opened_reason: @reason,
        created_by_membership: actor,
        status_changed_at: Time.current,
        status_changed_by_membership: actor
      )
    else
      commitment = @clause.affected_commitment
      commitment.update!(
        status: COMMITMENT_STATUSES.fetch(consequence.action),
        status_reason: @reason,
        status_changed_at: Time.current,
        status_changed_by_membership: actor
      )
      commitment
    end
  end

  def uuid?(value)
    value.match?(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i)
  end
end
