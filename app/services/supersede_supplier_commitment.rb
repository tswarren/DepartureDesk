class SupersedeSupplierCommitment < DepartureCommand
  def initialize(agency:, commitment:, governing_term:, reason:, valuation_inputs: {}, lock_version: nil, actor: nil, actor_identifier: nil, privileged: false)
    @agency = agency
    @commitment = commitment
    @governing_term = governing_term
    @departure = commitment.departure
    @reason = reason.to_s.strip
    @valuation_inputs = valuation_inputs || {}
    @lock_version = lock_version
    assign_command_actors(actor:, actor_identifier:, privileged:)
  end

  def call
    raise Error.new("A supersession reason is required.", code: :invalid) if @reason.blank?
    ActiveRecord::Base.transaction do
      with_departure_locks(
        @agency,
        offices: [ @commitment.office ],
        departure: @departure,
        supplier_arrangements: [ @commitment.arrangement ],
        supplier_cost_terms: [ @governing_term ],
        supplier_commitments: [ @commitment ]
      ) { perform }
    end
  rescue ActiveRecord::StaleObjectError
    raise Error.new("This supplier commitment was updated by someone else.", code: :conflict)
  rescue ActiveRecord::RecordInvalid => error
    raise Error.new(error.record.errors.full_messages.to_sentence, code: :invalid)
  rescue ActiveRecord::RecordNotUnique
    raise Error.new("An open supplier commitment already controls that economic item.", code: :conflict)
  end

  private

  def perform
    actor = actor_membership(@agency)
    ensure_office_access!(actor, @commitment.office)
    require_manager_or_administrator!(actor, @departure)
    ensure_fresh_lock!(@commitment, @lock_version)
    raise Error.new("Only open supplier commitments can be superseded.", code: :invalid_state) unless @commitment.open?
    raise Error.new("Replacement commitments require an active governing term.", code: :invalid_state) unless @governing_term.active?
    raise Error.new("Replacement term must govern the same economic item.", code: :invalid) unless @governing_term.economic_item_id == @commitment.economic_item_id

    @commitment.update!(status: "superseded", status_reason: @reason, status_changed_at: Time.current, status_changed_by_membership: actor)
    evaluation = SupplierCostTermEvaluation.evaluate(@governing_term, **@valuation_inputs.symbolize_keys.slice(:resource_quantity, :person_quantity, :night_count))
    replacement = @commitment.arrangement.supplier_commitments.create!(
      agency: @agency,
      office: @commitment.office,
      departure: @departure,
      reservation: @governing_term.reservation,
      resource: @governing_term.resource,
      service_occurrence: @governing_term.service_occurrence,
      governing_term: @governing_term,
      supersedes_commitment: @commitment,
      economic_item_id: @governing_term.economic_item_id,
      economic_item_key: @governing_term.economic_item_key,
      cost_category: @governing_term.cost_category,
      quantity_basis: @governing_term.quantity_basis,
      quantity_unit: @governing_term.quantity_unit,
      currency: evaluation.currency,
      valuation_amount_minor_units: evaluation.amount_minor_units,
      valuation_details: @valuation_inputs.merge("quantity" => evaluation.quantity, "explanation" => evaluation.explanation),
      governing_term_snapshot: @governing_term.display_snapshot,
      status: "open",
      opened_reason: @reason,
      created_by_membership: actor,
      status_changed_at: Time.current,
      status_changed_by_membership: actor
    )
    audit!(agency: @agency, action: "supplier_commitment.superseded", subject: replacement, details: { "superseded_supplier_commitment_id" => @commitment.id, "replacement_supplier_commitment_id" => replacement.id, "reason" => @reason }, **actor_audit_args)
    CommandResult.new(status: :accepted, departure: @departure, supplier_commitment: replacement)
  end
end
