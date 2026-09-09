class RestoreSupplierCapacity < SupplierCapacityCommand
  EVENT_TYPE = "restoration"
  DELTAS = { "consumed" => -1 }.freeze
  REQUIRES_RESERVATION = true
end
