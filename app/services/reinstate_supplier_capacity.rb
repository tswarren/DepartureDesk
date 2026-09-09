class ReinstateSupplierCapacity < SupplierCapacityCommand
  EVENT_TYPE = "reinstatement"
  DELTAS = { "agency_held" => 1, "released_current" => -1 }.freeze
  REQUIRES_APPROVAL = true
end
