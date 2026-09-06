class UpdateRoleProfile < RoleProfileCommand
  def initialize(agency:, party:, profile:, office:, lock_version: nil, actor: nil, actor_identifier: nil, privileged: false)
    @agency = agency
    @party = party
    @profile = profile
    @office = office
    @lock_version = lock_version
    assign_command_actors(actor:, actor_identifier:, privileged:)
  end

  def call
    with_directory_locks(@agency, parties: [ @party ], records: [ @profile ]) { perform }
  end

  private

  def perform
    ensure_profile_on_party!(@party, @profile)
    unless @profile.active?
      raise Error.new("Inactive roles cannot change office until they are reactivated.", code: :invalid)
    end

    lock_offices!(@agency, [ @profile.responsible_office, @office ])
    ensure_office_currently_active!(@office)
    ensure_fresh_lock!(@profile, @lock_version)

    if @profile.responsible_office_id == @office.id
      return profile_result(:accepted, @party, @profile)
    end

    previous_office_id = @profile.responsible_office_id
    @profile.update!(
      responsible_office: @office,
      responsible_office_status: "active"
    )
    audit_profile!(
      @profile,
      "directory.#{role_noun}_profile_updated",
      "previous_responsible_office_id" => previous_office_id
    )
    profile_result(:accepted, @party, @profile)
  end
end
