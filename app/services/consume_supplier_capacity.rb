class ConsumeSupplierCapacity < SupplierCapacityCommand
  EVENT_TYPE = "consumption"
  DELTAS = { "consumed" => 1 }.freeze
  REQUIRES_RESERVATION = true
end
