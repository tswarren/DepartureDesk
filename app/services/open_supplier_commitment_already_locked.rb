class OpenSupplierCommitmentAlreadyLocked
  IncompleteInputs = Class.new(StandardError)

  def initialize(trigger:, confirmation:, actor:, activation: nil,
    confirmed_quantity: nil, confirmed_amount_minor_units: nil,
    reservation: nil, revision: nil, scope: nil, response_event: nil,
    allow_unresolved: false)
    @trigger = trigger
    @confirmation = confirmation
    @actor = actor
    @activation = activation
    @confirmed_quantity = confirmed_quantity
    @confirmed_amount_minor_units = confirmed_amount_minor_units
    @reservation = reservation
    @revision = revision
    @scope = scope
    @response_event = response_event
    @allow_unresolved = allow_unresolved
  end

  # Internal operation only. The enclosing confirmation command must already
  # hold the complete owner, Supplier, trigger, and confirmation lock graph.
  # Returns nil when allow_unresolved and external inputs are incomplete.
  def call
    validate_owners!
    if @reservation && @scope.nil?
      raise AgencyCommand::Error.new("Reservation confirmation commitments require exact scope.", code: :invalid)
    end

    quantity, amount = authoritative_values
    commitment = SupplierCommitment.create!(
      owner_attributes.merge(
        supplier_arrangement_activation: @activation,
        supplier_commitment_trigger_definition: @trigger,
        supplier_confirmation: @confirmation,
        supplier_reservation: @reservation,
        supplier_reservation_revision: @revision,
        supplier_reservation_scope: @scope,
        supplier_reservation_event: @response_event,
        committed_supplier_id: @trigger.committed_supplier_id,
        commitment_type: commitment_type(quantity, amount),
        description: @trigger.description,
        quantity:,
        quantity_basis: quantity && @trigger.quantity_basis,
        amount_minor_units: amount,
        currency: amount && @trigger.currency,
        calculation_snapshot: calculation_snapshot(quantity, amount),
        actor: @actor,
        opened_at: Time.current
      )
    )
    SupplierConfirmationCommitmentLink.create!(
      owner_attributes.slice(
        :agency_id, :departure_id, :supplier_arrangement_id,
        :supplier_arrangement_version_id
      ).merge(
        supplier_confirmation: @confirmation,
        supplier_commitment: commitment
      )
    )
    commitment
  rescue IncompleteInputs
    nil
  rescue ActiveRecord::RecordNotUnique
    raise AgencyCommand::Error.new(
      "That confirmation already opened this commitment trigger.", code: :conflict
    )
  end

  private

  def validate_owners!
    owner_ids = %i[
      agency_id departure_id supplier_arrangement_id supplier_arrangement_version_id
    ]
    unless owner_ids.all? { |field| @trigger.public_send(field) == @confirmation.public_send(field) } &&
        @actor.agency_id == @trigger.agency_id &&
        @confirmation.confirming_supplier_id == @trigger.committed_supplier_id
      raise AgencyCommand::Error.new(
        "Confirmation is not compatible with the commitment trigger.", code: :invalid
      )
    end
    if @activation && owner_ids.any? { |field| @activation.public_send(field) != @trigger.public_send(field) }
      raise AgencyCommand::Error.new("Activation does not own this trigger.", code: :invalid)
    end
    return if @reservation.nil?

    unless @revision && @response_event && @scope &&
        @reservation.agency_id == @trigger.agency_id &&
        @reservation.departure_id == @trigger.departure_id &&
        @reservation.supplier_arrangement_id == @trigger.supplier_arrangement_id &&
        @revision.supplier_arrangement_version_id == @trigger.supplier_arrangement_version_id &&
        @response_event.supplier_reservation_id == @reservation.id
      raise AgencyCommand::Error.new("Reservation confirmation context is incomplete.", code: :invalid)
    end
  end

  def authoritative_values
    case @trigger.authority_shape
    when "fixed_quantity"
      [ @trigger.fixed_quantity, nil ]
    when "confirmed_quantity"
      [ positive_input(@confirmed_quantity, "confirmed quantity"), nil ]
    when "fixed_contracted_amount"
      [ nil, contracted_component_amount("fixed") ]
    when "confirmed_amount"
      [ nil, nonnegative_input(@confirmed_amount_minor_units, "confirmed amount") ]
    when "contracted_unit_rate_times_confirmed_quantity"
      quantity = positive_input(@confirmed_quantity, "confirmed quantity")
      [ quantity, contracted_component_amount("unit_rate") * quantity ]
    else
      raise incomplete_or_invalid!("Commitment authority is incomplete.")
    end
  end

  def contracted_component_amount(kind)
    definition = @trigger.supplier_cost_definition
    component = @trigger.supplier_cost_component
    unless definition&.contracted? && definition.forecast_ready? &&
        component&.supplier_charge? && component.calculation_kind == kind &&
        definition.currency == @trigger.currency
      raise incomplete_or_invalid!("The contracted monetary authority is no longer complete.")
    end
    component.amount_minor_units
  end

  def positive_input(value, label)
    number = Integer(value)
    raise ArgumentError unless number.positive?

    number
  rescue ArgumentError, TypeError
    raise incomplete_or_invalid!("Enter a positive whole #{label}.")
  end

  def nonnegative_input(value, label)
    number = Integer(value)
    raise ArgumentError if number.negative?

    number
  rescue ArgumentError, TypeError
    raise incomplete_or_invalid!("Enter a valid #{label} in minor units.")
  end

  def incomplete_or_invalid!(message)
    raise IncompleteInputs, message if @allow_unresolved

    raise AgencyCommand::Error.new(message, code: :invalid)
  end

  def commitment_type(quantity, amount)
    return "quantity_and_monetary" if quantity && amount

    quantity ? "quantity" : "monetary"
  end

  def calculation_snapshot(quantity, amount)
    [
      "authority=#{@trigger.authority_shape}",
      ("quantity=#{quantity}" if quantity),
      ("amount_minor_units=#{amount}" if amount),
      ("component_id=#{@trigger.supplier_cost_component_id}" if @trigger.supplier_cost_component_id)
    ].compact.join(";")
  end

  def owner_attributes
    {
      agency_id: @trigger.agency_id,
      departure_id: @trigger.departure_id,
      supplier_arrangement_id: @trigger.supplier_arrangement_id,
      supplier_arrangement_version_id: @trigger.supplier_arrangement_version_id,
      arrangement_item_id: @trigger.arrangement_item_id,
      service_occurrence_id: @trigger.service_occurrence_id,
      supplier_resource_id: @trigger.supplier_resource_id,
      capacity_pool_id: @trigger.capacity_pool_id,
      supplier_cost_source_id: @trigger.supplier_cost_source_id
    }
  end
end
