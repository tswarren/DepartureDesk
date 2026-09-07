class DeactivateExternalIdentifier < DirectoryCommand
  def initialize(agency:, party:, identifier:, reason:, actor: nil, actor_identifier: nil, privileged: false)
    @agency = agency
    @party = party
    @identifier = identifier
    @reason = reason.to_s.strip
    assign_command_actors(actor:, actor_identifier:, privileged:)
  end

  def call
    with_directory_locks(@agency, parties: [ @party ], records: [ @identifier ]) { perform }
  end

  private

  def perform
    ensure_identifier_on_party!
    return CommandResult.new(status: :accepted, party: @party) if @identifier.inactive?
    raise Error.new("Enter a reason for deactivation.", code: :invalid) if @reason.blank?

    @identifier.update!(
      status: "inactive",
      deactivated_at: Time.current,
      deactivated_by_membership: actor_membership!(@agency),
      deactivation_reason: @reason
    )
    audit!(
      agency: @agency,
      action: "directory.external_identifier_deactivated",
      subject: @identifier,
      details: {
        "party_id" => @party.id,
        "external_identifier_id" => @identifier.id,
        "identifier_type" => @identifier.identifier_type,
        "status" => @identifier.status
      },
      **actor_audit_args
    )
    CommandResult.new(status: :accepted, party: @party)
  end

  def ensure_identifier_on_party!
    owner_party = @identifier.owner_party
    return if owner_party&.id == @party.id && @identifier.agency_id == @agency.id

    raise Error.new("That identifier is not part of this party.", code: :not_found)
  end
end
