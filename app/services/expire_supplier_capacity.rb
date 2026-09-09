class ExpireSupplierCapacity < SupplierCapacityCommand
  EVENT_TYPE = "expiration"

  def initialize(held_quantity: nil, pending_quantity: nil, **attributes)
    @held_quantity_override = held_quantity
    @pending_quantity_override = pending_quantity
    super(**attributes)
  end

  private

  def validate_basic_inputs!
    super
    raise Error.new("Expired held capacity cannot be negative.", code: :invalid) if held_quantity.negative?
    raise Error.new("Expired pending capacity cannot be negative.", code: :invalid) if pending_quantity.negative?
    raise Error.new("Choose held or pending capacity to expire.", code: :invalid) if held_quantity.zero? && pending_quantity.zero?
    raise Error.new("Expired quantities must equal the command quantity.", code: :invalid) unless held_quantity + pending_quantity == @quantity
  end

  def event_deltas
    deltas = {
      "agency_held" => -held_quantity,
      "pending_request" => -pending_quantity,
      "released_current" => held_quantity
    }
    deltas.merge(guaranteed_delta)
  end

  def held_quantity
    Integer(@held_quantity_override.nil? ? @quantity : @held_quantity_override)
  end

  def pending_quantity
    Integer(@pending_quantity_override || 0)
  end

  def guaranteed_delta
    return {} if @guaranteed_quantity.zero?

    { "guaranteed" => -@guaranteed_quantity }
  end
end
