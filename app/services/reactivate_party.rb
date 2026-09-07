class ReactivateParty < DirectoryCommand
  def initialize(agency:, party:, reason:, lock_version: nil, actor: nil, actor_identifier: nil, privileged: false)
    @agency = agency
    @party = party
    @reason = reason.to_s.strip
    @lock_version = lock_version
    assign_command_actors(actor:, actor_identifier:, privileged:)
  end

  def call
    with_directory_locks(@agency, parties: [ @party ]) { perform }
  end

  private

  def perform
    return CommandResult.new(status: :accepted, party: @party) if @party.active?
    raise Error.new("Enter a reason for reactivation.", code: :invalid) if @reason.blank?

    if @lock_version.present? && @party.lock_version != @lock_version.to_i
      raise ActiveRecord::StaleObjectError.new(@party, "update")
    end

    @party.update!(
      status: "active",
      deactivated_at: nil,
      deactivated_by_membership: nil,
      deactivation_reason: nil
    )
    audit!(
      agency: @agency,
      action: "directory.party_reactivated",
      subject: @party,
      details: {
        "party_id" => @party.id,
        "party_kind" => @party.party_kind,
        "reason" => @reason
      },
      **actor_audit_args
    )
    CommandResult.new(status: :accepted, party: @party)
  end
end
