class CreateSupplierCommitment < DepartureCommand
  def initialize(agency:, governing_term:, reason:, valuation_inputs: {}, lock_version: nil, actor: nil, actor_identifier: nil, privileged: false)
    @agency = agency
    @governing_term = governing_term
    @departure = governing_term.departure
    @reason = reason.to_s.strip
    @valuation_inputs = valuation_inputs || {}
    @lock_version = lock_version
    assign_command_actors(actor:, actor_identifier:, privileged:)
  end

  def call
    raise Error.new("A commitment reason is required.", code: :invalid) if @reason.blank?
    ActiveRecord::Base.transaction do
      with_departure_locks(@agency, offices: [ @governing_term.office ], departure: @departure, supplier_arrangements: [ @governing_term.arrangement ], supplier_cost_terms: [ @governing_term ]) { perform }
    end
  rescue ActiveRecord::StaleObjectError
    raise Error.new("This supplier cost term was updated by someone else.", code: :conflict)
  rescue ActiveRecord::RecordInvalid => error
    raise Error.new(error.record.errors.full_messages.to_sentence, code: :invalid)
  rescue ActiveRecord::RecordNotUnique
    raise Error.new("An open supplier commitment already controls that economic item.", code: :conflict)
  end

  private

  def perform
    actor = actor_membership(@agency)
    ensure_office_access!(actor, @governing_term.office)
    require_manager_or_administrator!(actor, @departure)
    ensure_departure_can_receive_supplier_planning!(@departure)
    ensure_fresh_lock!(@governing_term, @lock_version)
    raise Error.new("Commitments require an active governing cost term.", code: :invalid_state) unless @governing_term.active?

    evaluation = SupplierCostTermEvaluation.evaluate(@governing_term, **symbolized_valuation_inputs)
    commitment = @governing_term.arrangement.supplier_commitments.create!(
      agency: @agency,
      office: @governing_term.office,
      departure: @departure,
      reservation: @governing_term.reservation,
      resource: @governing_term.resource,
      service_occurrence: @governing_term.service_occurrence,
      governing_term: @governing_term,
      economic_item_id: @governing_term.economic_item_id,
      economic_item_key: @governing_term.economic_item_key,
      cost_category: @governing_term.cost_category,
      quantity_basis: @governing_term.quantity_basis,
      quantity_unit: @governing_term.quantity_unit,
      currency: evaluation.currency,
      valuation_amount_minor_units: evaluation.amount_minor_units,
      valuation_details: @valuation_inputs.merge(
        "quantity" => evaluation.quantity,
        "explanation" => evaluation.explanation,
        "governing_term_id" => @governing_term.id
      ),
      governing_term_snapshot: @governing_term.display_snapshot,
      status: "open",
      opened_reason: @reason,
      created_by_membership: actor,
      status_changed_at: Time.current,
      status_changed_by_membership: actor
    )
    audit!(agency: @agency, action: "supplier_commitment.opened", subject: commitment, details: { "supplier_commitment_id" => commitment.id, "governing_term_id" => @governing_term.id, "amount_minor_units" => commitment.valuation_amount_minor_units, "currency" => commitment.currency }, **actor_audit_args)
    CommandResult.new(status: :created, departure: @departure, supplier_commitment: commitment)
  end

  def symbolized_valuation_inputs
    @valuation_inputs.symbolize_keys.slice(:resource_quantity, :person_quantity, :night_count, :qualifying_quantity, :base_amount_minor_units)
  end
end
