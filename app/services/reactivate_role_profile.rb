class ReactivateRoleProfile < RoleProfileCommand
  def initialize(agency:, party:, profile:, office:, lock_version: nil, actor: nil, actor_identifier: nil, privileged: false)
    @agency = agency
    @party = party
    @profile = profile
    @office = office
    @lock_version = lock_version
    assign_command_actors(actor:, actor_identifier:, privileged:)
  end

  def call
    with_directory_locks(@agency, parties: [ @party ], records: [ @profile ], offices: [ @office ]) { perform }
  end

  private

  def perform
    ensure_profile_on_party!(@party, @profile)
    return profile_result(:accepted, @party, @profile) if @profile.active?

    ensure_party_can_hold_active_role!(@party)
    ensure_office_currently_active!(@office)
    ensure_fresh_lock!(@profile, @lock_version)
    @profile.update!(
      status: "active",
      party_status: "active",
      responsible_office: @office,
      responsible_office_status: "active",
      deactivated_at: nil,
      deactivated_by_membership: nil,
      deactivation_reason: nil
    )
    audit_profile!(@profile, "directory.#{role_noun}_profile_reactivated")
    profile_result(:accepted, @party, @profile)
  end
end
