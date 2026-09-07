class ClearClientAdvisor < ClientAdvisorCommand
  def initialize(agency:, party:, profile:, lock_version: nil, actor: nil, actor_identifier: nil, privileged: false)
    @agency = agency
    @party = party
    @profile = profile
    @lock_version = lock_version
    assign_command_actors(actor:, actor_identifier:, privileged:)
  end

  def call
    with_directory_locks(
      @agency,
      parties: [ @party ],
      records: [ @profile ],
      memberships: [ @profile.primary_advisor_membership ].compact
    ) { perform }
  end

  private

  def perform
    ensure_profile_on_party!(@party, @profile)
    unless @profile.active?
      raise Error.new("Inactive roles cannot change advisor until they are reactivated.", code: :invalid)
    end
    ensure_fresh_lock!(@profile, @lock_version)

    if @profile.primary_advisor_membership_id.blank?
      return profile_result(:accepted, @party, @profile)
    end

    previous_id = @profile.primary_advisor_membership_id
    assignment = @profile.open_advisor_assignment
    end_open_assignment!(@profile, reason: "Advisor cleared")
    set_current_advisor!(@profile, nil)
    audit!(
      agency: @agency,
      action: "directory.client_advisor_cleared",
      subject: assignment || @profile,
      details: {
        "party_id" => @profile.party_id,
        "client_profile_id" => @profile.id,
        "previous_advisor_membership_id" => previous_id
      },
      **actor_audit_args
    )
    profile_result(:accepted, @party, @profile)
  end
end
