class CreateSupplierClause < DepartureCommand
  def initialize(
    agency:,
    arrangement:,
    clause_type:,
    name:,
    capacity_action: "none",
    capacity_quantity: nil,
    guaranteed_quantity: nil,
    commitment_action: "none",
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
    @arrangement = arrangement
    @departure = arrangement.departure
    @clause_type = clause_type.to_s
    @name = name
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
        offices: [ @arrangement.office ],
        departure: @departure,
        supplier_arrangements: [ @arrangement ],
        supplier_resources: [ @resource ],
        supplier_service_occurrences: [ @service_occurrence ],
        supplier_cost_terms: [ @governing_term ],
        supplier_commitments: [ @affected_commitment ]
      ) { perform }
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
    ensure_departure_can_receive_supplier_planning!(@departure)
    ensure_fresh_lock!(@arrangement, @lock_version)
    raise Error.new("Clauses can only be added under nonterminal arrangements.", code: :invalid_state) unless @arrangement.nonterminal?
    raise Error.new("Choose a supported clause type.", code: :invalid) unless SupplierClause::CLAUSE_TYPES.include?(@clause_type)

    clause = @arrangement.supplier_clauses.create!(
      agency: @agency,
      office: @arrangement.office,
      departure: @departure,
      resource_id: @resource&.id,
      service_occurrence_id: @service_occurrence&.id,
      governing_term_id: @governing_term&.id,
      affected_commitment_id: @affected_commitment&.id,
      clause_type: @clause_type,
      name: @name,
      capacity_action: @capacity_action,
      capacity_quantity: @capacity_quantity,
      guaranteed_quantity: @guaranteed_quantity,
      commitment_action: @commitment_action,
      amount_minor_units: @amount_minor_units,
      currency: @currency.present? ? known_currency!(@currency) : nil,
      effective_on: @effective_on,
      effective_until: @effective_until,
      trigger_on: @trigger_on,
      deadline_due_on: @deadline_due_on,
      provenance: @provenance,
      application_rules: @application_rules,
      created_by_membership: actor
    )

    audit!(agency: @agency, action: "supplier_clause.created", subject: clause, details: details_for(clause), **actor_audit_args)
    CommandResult.new(status: :created, departure: @departure, supplier_clause: clause)
  end

  def details_for(clause)
    {
      "supplier_clause_id" => clause.id,
      "supplier_arrangement_id" => @arrangement.id,
      "clause_type" => clause.clause_type,
      "capacity_action" => clause.capacity_action,
      "commitment_action" => clause.commitment_action
    }
  end
end
