class DeactivateParty < DirectoryCommand
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
    return CommandResult.new(status: :accepted, party: @party) if @party.deactivated?
    raise Error.new("Enter a reason for deactivation.", code: :invalid) if @reason.blank?

    if @lock_version.present? && @party.lock_version != @lock_version.to_i
      raise ActiveRecord::StaleObjectError.new(@party, "update")
    end

    dependencies = PartyDeactivationDependencies.new(agency: @agency, party: @party)
    if dependencies.blocked?
      raise Error.new(dependencies.message, code: :party_dependency)
    end

    @party.update!(
      status: "deactivated",
      deactivated_at: Time.current,
      deactivated_by_membership: actor_membership!(@agency),
      deactivation_reason: @reason
    )
    audit!(
      agency: @agency,
      action: "directory.party_deactivated",
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

  def party_status_fk_error
    Error.new(PartyDeactivationDependencies.new(agency: @agency, party: @party.reload).message, code: :party_dependency)
  end
end
