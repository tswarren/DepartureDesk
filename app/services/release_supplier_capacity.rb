class ReleaseSupplierCapacity < SupplierCapacityCommand
  EVENT_TYPE = "release"
  DELTAS = { "agency_held" => -1, "released_current" => 1 }.freeze
  GUARANTEE_SIGN = -1
end
