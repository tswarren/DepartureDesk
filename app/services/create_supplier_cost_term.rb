class CreateSupplierCostTerm < DepartureCommand
  DETAIL_BUILDERS = {
    "fixed" => :build_fixed_detail,
    "per_resource" => :build_per_resource_detail,
    "per_person" => :build_per_person_detail,
    "per_night" => :build_per_night_detail,
    "minimum_guarantee" => :build_minimum_guarantee_detail,
    "manual_estimate" => :build_manual_estimate_detail
  }.freeze

  def initialize(agency:, arrangement:, shape:, basis:, cost_category:, quantity_basis:, quantity_unit:, currency: nil, detail_attributes:, reservation: nil, resource: nil, service_occurrence: nil, effective_on: nil, effective_until: nil, rounding_method: "nearest_minor_unit", tax_fee_treatment: "excluded", source_reference: nil, provenance:, evaluation_inputs: {}, lock_version: nil, actor: nil, actor_identifier: nil, privileged: false)
    @agency = agency
    @arrangement = arrangement
    @departure = arrangement.departure
    @shape = shape.to_s
    @basis = basis.to_s
    @cost_category = cost_category
    @quantity_basis = quantity_basis
    @quantity_unit = quantity_unit
    @currency = currency || @departure.default_currency
    @detail_attributes = detail_attributes || {}
    @reservation = reservation
    @resource = resource
    @service_occurrence = service_occurrence
    @effective_on = effective_on
    @effective_until = effective_until
    @rounding_method = rounding_method
    @tax_fee_treatment = tax_fee_treatment
    @source_reference = source_reference
    @provenance = provenance
    @evaluation_inputs = evaluation_inputs || {}
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
        supplier_reservations: [ @reservation ],
        supplier_resources: [ @resource ],
        supplier_service_occurrences: [ @service_occurrence ]
      ) { perform }
    end
  rescue ActiveRecord::StaleObjectError
    raise Error.new("This supplier arrangement was updated by someone else.", code: :conflict)
  rescue ActiveRecord::RecordInvalid => error
    raise Error.new(error.record.errors.full_messages.to_sentence, code: :invalid)
  rescue ActiveRecord::RecordNotUnique
    raise Error.new("An active supplier cost term already exists for that economic item.", code: :conflict)
  end

  private

  def perform
    actor = actor_membership(@agency)
    ensure_office_access!(actor, @arrangement.office)
    ensure_departure_can_receive_supplier_planning!(@departure)
    ensure_fresh_lock!(@arrangement, @lock_version)
    raise Error.new("Cost terms can only be added under nonterminal arrangements.", code: :invalid_state) unless @arrangement.nonterminal?
    ensure_supported_shape!
    currency = known_currency!(@currency)
    key = SupplierCostTerm.economic_item_key_for(
      arrangement: @arrangement,
      reservation: @reservation,
      resource: @resource,
      service_occurrence: @service_occurrence,
      cost_category: @cost_category,
      quantity_basis: @quantity_basis,
      quantity_unit: @quantity_unit,
      currency:
    )

    term = @arrangement.supplier_cost_terms.build(
      agency: @agency,
      office: @arrangement.office,
      departure: @departure,
      reservation: @reservation,
      resource: @resource,
      service_occurrence: @service_occurrence,
      economic_item_key: key,
      cost_category: @cost_category,
      quantity_basis: @quantity_basis,
      quantity_unit: @quantity_unit,
      shape: @shape,
      basis: @basis,
      status: "draft",
      currency:,
      effective_on: @effective_on,
      effective_until: @effective_until,
      rounding_method: @rounding_method,
      tax_fee_treatment: @tax_fee_treatment,
      source_reference: @source_reference,
      provenance: @provenance,
      evaluation_inputs: @evaluation_inputs,
      created_by_membership: actor,
      status_changed_at: Time.current,
      status_changed_by_membership: actor
    )
    term.public_send(DETAIL_BUILDERS.fetch(@shape), @detail_attributes.merge(agency: @agency))
    term.save!
    audit!(agency: @agency, action: "supplier_cost_term.created", subject: term, details: details_for(term), **actor_audit_args)
    CommandResult.new(status: :created, departure: @departure, supplier_cost_term: term)
  end

  def ensure_supported_shape!
    return if DETAIL_BUILDERS.key?(@shape)

    raise Error.new("Choose a supported cost term shape.", code: :invalid)
  end

  def details_for(term)
    {
      "supplier_cost_term_id" => term.id,
      "supplier_arrangement_id" => @arrangement.id,
      "economic_item_key" => term.economic_item_key,
      "shape" => term.shape,
      "basis" => term.basis
    }
  end
end
