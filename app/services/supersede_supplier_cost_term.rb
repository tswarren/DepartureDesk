class SupersedeSupplierCostTerm < DepartureCommand
  DETAIL_BUILDERS = CreateSupplierCostTerm::DETAIL_BUILDERS

  def initialize(agency:, term:, shape: nil, basis: nil, cost_category: nil, quantity_basis: nil, quantity_unit: nil, currency: nil, detail_attributes:, effective_on: nil, effective_until: nil, rounding_method: nil, tax_fee_treatment: nil, source_reference: nil, provenance:, evaluation_inputs: nil, reason:, lock_version: nil, actor: nil, actor_identifier: nil, privileged: false)
    @agency = agency
    @term = term
    @departure = term.departure
    @shape = (shape || term.shape).to_s
    @basis = (basis || term.basis).to_s
    @cost_category = cost_category || term.cost_category
    @quantity_basis = quantity_basis || term.quantity_basis
    @quantity_unit = quantity_unit || term.quantity_unit
    @currency = currency || term.currency
    @detail_attributes = detail_attributes || {}
    @effective_on = effective_on || term.effective_on
    @effective_until = effective_until
    @rounding_method = rounding_method || term.rounding_method
    @tax_fee_treatment = tax_fee_treatment || term.tax_fee_treatment
    @source_reference = source_reference
    @provenance = provenance
    @evaluation_inputs = evaluation_inputs || term.evaluation_inputs
    @reason = reason.to_s.strip
    @lock_version = lock_version
    assign_command_actors(actor:, actor_identifier:, privileged:)
  end

  def call
    raise Error.new("A supersession reason is required.", code: :invalid) if @reason.blank?
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
    raise Error.new("Only active supplier cost terms can be superseded.", code: :invalid_state) unless @term.active?
    raise Error.new("Choose a supported cost term shape.", code: :invalid) unless DETAIL_BUILDERS.key?(@shape)
    currency = known_currency!(@currency)

    @term.update!(status: "superseded", status_reason: @reason, status_changed_at: Time.current, status_changed_by_membership: actor)
    replacement = @term.arrangement.supplier_cost_terms.build(
      agency: @agency,
      office: @term.office,
      departure: @departure,
      reservation: @term.reservation,
      resource: @term.resource,
      service_occurrence: @term.service_occurrence,
      economic_item_id: @term.economic_item_id,
      economic_item_key: SupplierCostTerm.economic_item_key_for(
        arrangement: @term.arrangement,
        reservation: @term.reservation,
        resource: @term.resource,
        service_occurrence: @term.service_occurrence,
        cost_category: @cost_category,
        quantity_basis: @quantity_basis,
        quantity_unit: @quantity_unit,
        currency:
      ),
      cost_category: @cost_category,
      quantity_basis: @quantity_basis,
      quantity_unit: @quantity_unit,
      shape: @shape,
      basis: @basis,
      status: "active",
      currency:,
      effective_on: @effective_on,
      effective_until: @effective_until,
      term_version: @term.term_version + 1,
      rounding_method: @rounding_method,
      tax_fee_treatment: @tax_fee_treatment,
      source_reference: @source_reference,
      provenance: @provenance,
      evaluation_inputs: @evaluation_inputs,
      supersedes_term: @term,
      created_by_membership: actor,
      status_changed_at: Time.current,
      status_changed_by_membership: actor
    )
    replacement.public_send(DETAIL_BUILDERS.fetch(@shape), @detail_attributes.merge(agency: @agency))
    replacement.save!
    audit!(agency: @agency, action: "supplier_cost_term.superseded", subject: replacement, details: { "superseded_supplier_cost_term_id" => @term.id, "replacement_supplier_cost_term_id" => replacement.id, "reason" => @reason }, **actor_audit_args)
    CommandResult.new(status: :accepted, departure: @departure, supplier_cost_term: replacement)
  end
end
