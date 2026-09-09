class CancelSupplierDeadline < ChangeSupplierDeadlineStatus
  def initialize(agency:, deadline:, reason:, lock_version: nil, actor: nil, actor_identifier: nil, privileged: false)
    super(agency:, deadline:, status: "cancelled", reason:, lock_version:, actor:, actor_identifier:, privileged:)
  end
end
