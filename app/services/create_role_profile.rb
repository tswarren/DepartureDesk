class CreateRoleProfile < RoleProfileCommand
  def initialize(agency:, party:, office:, actor: nil, actor_identifier: nil, privileged: false)
    @agency = agency
    @party = party
    @office = office
    assign_command_actors(actor:, actor_identifier:, privileged:)
  end

  def call
    existing = profile_class.find_by(agency_id: @agency.id, party_id: @party.id)
    with_directory_locks(@agency, parties: [ @party ], records: [ existing ].compact, offices: [ @office ]) { perform }
  end

  private

  def perform
    ensure_role_kind_allowed!(@party)
    ensure_party_can_hold_active_role!(@party)
    existing = existing_profile_for(@party)
    if existing
      if existing.inactive?
        raise Error.new(
          "This party already has an inactive #{role_noun} role. Reactivate it instead.",
          code: :reactivate
        )
      end

      raise Error.new("That directory record already exists.", code: :conflict)
    end
    ensure_office_currently_active!(@office)

    profile = profile_class.create!(create_attributes)
    audit_profile!(profile, "directory.#{role_noun}_profile_created")
    profile_result(:created, @party, profile)
  end

  def create_attributes
    {
      agency: @agency,
      party: @party,
      party_kind: @party.party_kind,
      status: "active",
      responsible_office: @office,
      responsible_office_status: "active"
    }
  end

  def ensure_role_kind_allowed!(party)
    return if profile_class::PARTY_KINDS.include?(party.party_kind)

    raise Error.new("This party cannot hold a #{role_noun} role.", code: :invalid)
  end
end
