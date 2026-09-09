class ReduceSupplierCapacity < SupplierCapacityCommand
  EVENT_TYPE = "reduction"
  DELTAS = { "agency_held" => -1 }.freeze
  GUARANTEE_SIGN = -1
end
