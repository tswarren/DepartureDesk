class AssignClientAdvisor < ClientAdvisorCommand
  def initialize(agency:, party:, profile:, membership:, lock_version: nil, actor: nil, actor_identifier: nil, privileged: false)
    @agency = agency
    @party = party
    @profile = profile
    @membership = membership
    @lock_version = lock_version
    assign_command_actors(actor:, actor_identifier:, privileged:)
  end

  def call
    with_directory_locks(
      @agency,
      parties: [ @party ],
      records: [ @profile ],
      memberships: [ @membership ]
    ) { perform }
  end

  private

  def perform
    ensure_profile_on_party!(@party, @profile)
    unless @profile.active?
      raise Error.new("Inactive roles cannot change advisor until they are reactivated.", code: :invalid)
    end
    ensure_assignable_advisor!(@membership)
    ensure_fresh_lock!(@profile, @lock_version)

    if @profile.primary_advisor_membership_id == @membership.id
      return profile_result(:accepted, @party, @profile)
    end

    previous_id = @profile.primary_advisor_membership_id
    today = DirectoryDate.today(@agency)
    end_open_assignment!(@profile, reason: "Advisor reassigned")
    assignment = ClientAdvisorAssignment.create!(
      agency: @agency,
      client_profile: @profile,
      advisor_membership: @membership,
      effective_from: today
    )
    set_current_advisor!(@profile, @membership)
    audit!(
      agency: @agency,
      action: previous_id.present? ? "directory.client_advisor_reassigned" : "directory.client_advisor_assigned",
      subject: assignment,
      details: {
        "party_id" => @profile.party_id,
        "client_profile_id" => @profile.id,
        "advisor_membership_id" => @membership.id,
        "previous_advisor_membership_id" => previous_id,
        "effective_from" => today.iso8601
      },
      **actor_audit_args
    )
    profile_result(:accepted, @party, @profile)
  end
end
