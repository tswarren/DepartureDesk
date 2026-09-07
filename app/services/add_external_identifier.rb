class AddExternalIdentifier < DirectoryCommand
  def initialize(agency:, party:, identifier_type:, original_value:, issuer: nil, source: "staff", actor: nil, actor_identifier: nil, privileged: false)
    @agency = agency
    @party = party
    @identifier_type = identifier_type.to_s
    @original_value = original_value
    @issuer = issuer
    @source = source.to_s
    assign_command_actors(actor:, actor_identifier:, privileged:)
  end

  def call
    with_directory_locks(@agency, parties: [ @party ], records: owner_records) { perform }
  end

  private

  def perform
    unless ExternalIdentifierRegistry.known?(@identifier_type)
      raise Error.new("Choose an identifier type.", code: :invalid)
    end
    definition = ExternalIdentifierRegistry.type!(@identifier_type)
    profile = owner_profile(definition)
    if definition.owner != :party && profile.nil?
      raise Error.new("That identifier type requires an active #{definition.owner.to_s.humanize.downcase}.", code: :invalid)
    end
    if definition.owner != :party && !profile.active?
      raise Error.new("Inactive roles cannot receive current identifiers.", code: :invalid)
    end

    identifier = ExternalIdentifier.create!(
      agency: @agency,
      party_id: definition.owner == :party ? @party.id : nil,
      client_profile_id: definition.owner == :client_profile ? profile.id : nil,
      supplier_profile_id: definition.owner == :supplier_profile ? profile.id : nil,
      office_id: nil,
      identifier_type: definition.code,
      issuer: @issuer,
      original_value: @original_value,
      normalized_value: ExternalIdentifierRegistry.normalize(definition.code, @original_value),
      normalization_version: definition.normalization_version,
      status: "active",
      source: @source
    )
    audit!(
      agency: @agency,
      action: "directory.external_identifier_created",
      subject: identifier,
      details: {
        "party_id" => @party.id,
        "external_identifier_id" => identifier.id,
        "identifier_type" => identifier.identifier_type,
        "status" => identifier.status,
        "owner" => definition.owner.to_s
      },
      **actor_audit_args
    )
    CommandResult.new(status: :created, party: @party)
  end

  def owner_profile(definition)
    case definition.owner
    when :client_profile then @party.client_profile
    when :supplier_profile then @party.supplier_profile
    end
  end

  def owner_records
    return [] unless ExternalIdentifierRegistry.known?(@identifier_type)

    case ExternalIdentifierRegistry.type!(@identifier_type).owner
    when :client_profile then [ @party.client_profile ]
    when :supplier_profile then [ @party.supplier_profile ]
    else []
    end
  end
end
