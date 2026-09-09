class IncreaseSupplierCapacity < SupplierCapacityCommand
  EVENT_TYPE = "increase"
  DELTAS = { "agency_held" => 1 }.freeze
end
