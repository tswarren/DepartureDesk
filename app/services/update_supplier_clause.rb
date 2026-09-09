class UpdateSupplierClause < DepartureCommand
  EDITABLE = %w[
    name clause_type capacity_action capacity_quantity guaranteed_quantity commitment_action
    amount_minor_units currency resource_id service_occurrence_id governing_term_id affected_commitment_id
    effective_on effective_until trigger_on deadline_due_on provenance application_rules
  ].freeze

  def initialize(
    agency:,
    clause:,
    name:,
    clause_type:,
    capacity_action:,
    capacity_quantity: nil,
    guaranteed_quantity: nil,
    commitment_action:,
    amount_minor_units: nil,
    currency: nil,
    resource: nil,
    service_occurrence: nil,
    governing_term: nil,
    affected_commitment: nil,
    effective_on: nil,
    effective_until: nil,
    trigger_on: nil,
    deadline_due_on: nil,
    provenance:,
    application_rules: {},
    lock_version: nil,
    actor: nil,
    actor_identifier: nil,
    privileged: false
  )
    @agency = agency
    @clause = clause
    @departure = clause.departure
    @name = name
    @clause_type = clause_type.to_s
    @capacity_action = capacity_action.to_s
    @capacity_quantity = capacity_quantity
    @guaranteed_quantity = guaranteed_quantity
    @commitment_action = commitment_action.to_s
    @amount_minor_units = amount_minor_units
    @currency = currency
    @resource = resource
    @service_occurrence = service_occurrence
    @governing_term = governing_term
    @affected_commitment = affected_commitment
    @effective_on = effective_on
    @effective_until = effective_until
    @trigger_on = trigger_on
    @deadline_due_on = deadline_due_on
    @provenance = provenance
    @application_rules = application_rules || {}
    @lock_version = lock_version
    assign_command_actors(actor:, actor_identifier:, privileged:)
  end

  def call
    ActiveRecord::Base.transaction do
      with_departure_locks(
        @agency,
        offices: [ @clause.office ],
        departure: @departure,
        supplier_arrangements: [ @clause.arrangement ],
        supplier_clauses: [ @clause ],
        supplier_resources: [ @resource ],
        supplier_service_occurrences: [ @service_occurrence ],
        supplier_cost_terms: [ @governing_term ],
        supplier_commitments: [ @affected_commitment ]
      ) { perform }
    end
  rescue ActiveRecord::StaleObjectError
    raise Error.new("This supplier clause was updated by someone else.", code: :conflict)
  rescue ActiveRecord::RecordInvalid => error
    raise Error.new(error.record.errors.full_messages.to_sentence, code: :invalid)
  end

  private

  def perform
    actor = actor_membership(@agency)
    ensure_office_access!(actor, @clause.office)
    ensure_departure_can_receive_supplier_planning!(@departure)
    ensure_fresh_lock!(@clause, @lock_version)
    raise Error.new("Clauses can only be updated under nonterminal arrangements.", code: :invalid_state) unless @clause.arrangement.nonterminal?

    before = snapshot
    @clause.update!(
      name: @name,
      clause_type: @clause_type,
      capacity_action: @capacity_action,
      capacity_quantity: @capacity_quantity,
      guaranteed_quantity: @guaranteed_quantity,
      commitment_action: @commitment_action,
      amount_minor_units: @amount_minor_units,
      currency: @currency.present? ? known_currency!(@currency) : nil,
      resource_id: @resource&.id,
      service_occurrence_id: @service_occurrence&.id,
      governing_term_id: @governing_term&.id,
      affected_commitment_id: @affected_commitment&.id,
      effective_on: @effective_on,
      effective_until: @effective_until,
      trigger_on: @trigger_on,
      deadline_due_on: @deadline_due_on,
      provenance: @provenance,
      application_rules: @application_rules
    )
    after = snapshot
    changed = EDITABLE.select { |field| before[field] != after[field] }
    if changed.any?
      audit!(agency: @agency, action: "supplier_clause.updated", subject: @clause, details: { "supplier_clause_id" => @clause.id, "changed_fields" => changed, "before" => before.slice(*changed), "after" => after.slice(*changed) }, **actor_audit_args)
    end
    CommandResult.new(status: :accepted, departure: @departure, supplier_clause: @clause)
  end

  def snapshot
    @clause.attributes.slice(*EDITABLE)
  end
end
