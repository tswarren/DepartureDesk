class ConfirmSupplierCapacityRequest < SupplierCapacityCommand
  EVENT_TYPE = "confirm_request"
  DELTAS = { "agency_held" => 1, "pending_request" => -1 }.freeze
end
