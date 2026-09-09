class HoldSupplierCapacity < SupplierCapacityCommand
  EVENT_TYPE = "initial_hold"
  DELTAS = { "agency_held" => 1 }.freeze
  CAN_INITIALIZE_POSITION = true
end
