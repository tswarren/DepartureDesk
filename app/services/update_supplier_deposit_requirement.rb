class UpdateSupplierDepositRequirement < DepartureCommand
  EDITABLE = %w[name amount_minor_units currency due_rule due_on refundable applies_to_final_balance trigger_condition provenance supplier_cost_term_id].freeze

  def initialize(agency:, deposit_requirement:, name:, amount_minor_units:, currency:, due_rule:, due_on: nil, refundable:, applies_to_final_balance:, trigger_condition:, provenance:, supplier_cost_term: nil, lock_version: nil, actor: nil, actor_identifier: nil, privileged: false)
    @agency = agency
    @deposit = deposit_requirement
    @departure = deposit_requirement.departure
    @name = name
    @amount_minor_units = amount_minor_units
    @currency = currency
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
      with_departure_locks(@agency, offices: [ @deposit.office ], departure: @departure, supplier_arrangements: [ @deposit.arrangement ], supplier_cost_terms: [ @supplier_cost_term ], supplier_deposit_requirements: [ @deposit ]) { perform }
    end
  rescue ActiveRecord::StaleObjectError
    raise Error.new("This supplier deposit requirement was updated by someone else.", code: :conflict)
  rescue ActiveRecord::RecordInvalid => error
    raise Error.new(error.record.errors.full_messages.to_sentence, code: :invalid)
  end

  private

  def perform
    actor = actor_membership(@agency)
    ensure_office_access!(actor, @deposit.office)
    ensure_departure_can_receive_supplier_planning!(@departure)
    ensure_fresh_lock!(@deposit, @lock_version)
    raise Error.new("Only active deposit requirements can be updated.", code: :invalid_state) unless @deposit.active?

    before = snapshot
    @deposit.update!(
      supplier_cost_term: @supplier_cost_term,
      name: @name,
      amount_minor_units: @amount_minor_units,
      currency: known_currency!(@currency),
      due_rule: @due_rule,
      due_on: @due_on,
      refundable: @refundable,
      applies_to_final_balance: @applies_to_final_balance,
      trigger_condition: @trigger_condition,
      provenance: @provenance
    )
    after = snapshot
    changed = EDITABLE.select { |field| before[field] != after[field] }
    if changed.any?
      audit!(agency: @agency, action: "supplier_deposit_requirement.updated", subject: @deposit, details: { "supplier_deposit_requirement_id" => @deposit.id, "changed_fields" => changed, "before" => before.slice(*changed), "after" => after.slice(*changed) }, **actor_audit_args)
    end
    CommandResult.new(status: :accepted, departure: @departure, supplier_deposit_requirement: @deposit)
  end

  def snapshot
    @deposit.attributes.slice(*EDITABLE)
  end
end
