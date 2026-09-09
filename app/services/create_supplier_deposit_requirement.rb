class CreateSupplierDepositRequirement < DepartureCommand
  def initialize(agency:, arrangement:, name:, amount_minor_units:, currency: nil, due_rule:, due_on: nil, refundable: false, applies_to_final_balance: true, trigger_condition:, provenance:, supplier_cost_term: nil, lock_version: nil, actor: nil, actor_identifier: nil, privileged: false)
    @agency = agency
    @arrangement = arrangement
    @departure = arrangement.departure
    @name = name
    @amount_minor_units = amount_minor_units
    @currency = currency || @departure.default_currency
    @due_rule = due_rule
    @due_on = due_on
    @refundable = refundable
    @applies_to_final_balance = applies_to_final_balance
    @trigger_condition = trigger_condition
    @provenance = provenance
    @supplier_cost_term = supplier_cost_term
    @lock_version = lock_version
    assign_command_actors(actor:, actor_identifier:, privileged:)
  end

  def call
    ActiveRecord::Base.transaction do
      with_departure_locks(@agency, offices: [ @arrangement.office ], departure: @departure, supplier_arrangements: [ @arrangement ], supplier_cost_terms: [ @supplier_cost_term ]) { perform }
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
    raise Error.new("Deposit requirements can only be added under nonterminal arrangements.", code: :invalid_state) unless @arrangement.nonterminal?

    deposit = @arrangement.supplier_deposit_requirements.create!(
      agency: @agency,
      office: @arrangement.office,
      departure: @departure,
      supplier_cost_term: @supplier_cost_term,
      name: @name,
      amount_minor_units: @amount_minor_units,
      currency: known_currency!(@currency),
      due_rule: @due_rule,
      due_on: @due_on,
      refundable: @refundable,
      applies_to_final_balance: @applies_to_final_balance,
      trigger_condition: @trigger_condition,
      provenance: @provenance,
      status: "active",
      created_by_membership: actor,
      status_changed_by_membership: actor,
      status_changed_at: Time.current
    )
    audit!(agency: @agency, action: "supplier_deposit_requirement.created", subject: deposit, details: { "supplier_deposit_requirement_id" => deposit.id, "supplier_arrangement_id" => @arrangement.id }, **actor_audit_args)
    CommandResult.new(status: :created, departure: @departure, supplier_deposit_requirement: deposit)
  end
end
