class RequestSupplierCapacity < SupplierCapacityCommand
  EVENT_TYPE = "request"
  DELTAS = { "pending_request" => 1 }.freeze
  CAN_INITIALIZE_POSITION = true
end
