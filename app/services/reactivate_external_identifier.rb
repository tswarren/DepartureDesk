class ReactivateExternalIdentifier < DirectoryCommand
  def initialize(agency:, party:, identifier:, actor: nil, actor_identifier: nil, privileged: false)
    @agency = agency
    @party = party
    @identifier = identifier
    assign_command_actors(actor:, actor_identifier:, privileged:)
  end

  def call
    with_directory_locks(@agency, parties: [ @party ], records: [ @identifier ]) { perform }
  end

  private

  def perform
    owner_party = @identifier.owner_party
    unless owner_party&.id == @party.id && @identifier.agency_id == @agency.id
      raise Error.new("That identifier is not part of this party.", code: :not_found)
    end
    return CommandResult.new(status: :accepted, party: @party) if @identifier.active?

    if @identifier.client_profile && !@identifier.client_profile.active?
      raise Error.new("Inactive roles cannot receive current identifiers.", code: :invalid)
    end
    if @identifier.supplier_profile && !@identifier.supplier_profile.active?
      raise Error.new("Inactive roles cannot receive current identifiers.", code: :invalid)
    end

    @identifier.update!(
      status: "active",
      deactivated_at: nil,
      deactivated_by_membership: nil,
      deactivation_reason: nil
    )
    audit!(
      agency: @agency,
      action: "directory.external_identifier_reactivated",
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
end
