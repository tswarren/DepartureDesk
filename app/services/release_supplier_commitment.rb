class ReleaseSupplierCommitment < ChangeSupplierCommitmentStatus
  def initialize(agency:, commitment:, reason:, lock_version: nil, actor: nil, actor_identifier: nil, privileged: false)
    super(agency:, commitment:, status: "released", reason:, lock_version:, actor:, actor_identifier:, privileged:)
  end
end
