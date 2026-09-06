class DeactivateRoleProfile < RoleProfileCommand
  def initialize(agency:, party:, profile:, reason:, lock_version: nil, actor: nil, actor_identifier: nil, privileged: false)
    @agency = agency
    @party = party
    @profile = profile
    @reason = reason.to_s.strip
    @lock_version = lock_version
    assign_command_actors(actor:, actor_identifier:, privileged:)
  end

  def call
    with_directory_locks(@agency, parties: [ @party ], records: [ @profile ]) { perform }
  end

  private

  def perform
    ensure_profile_on_party!(@party, @profile)
    return profile_result(:accepted, @party, @profile) if @profile.inactive?
    raise Error.new("Enter a reason for deactivation.", code: :invalid) if @reason.blank?

    ensure_fresh_lock!(@profile, @lock_version)
    @profile.update!(
      status: "inactive",
      responsible_office_status: nil,
      deactivated_at: Time.current,
      deactivated_by_membership: actor_membership!(@agency),
      deactivation_reason: @reason
    )
    audit_profile!(@profile, "directory.#{role_noun}_profile_deactivated")
    profile_result(:accepted, @party, @profile)
  end
end
