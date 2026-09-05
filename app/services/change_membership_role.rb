class ChangeMembershipRole < MembershipCommand
  def initialize(agency:, membership:, role:, actor: nil, actor_identifier: nil, privileged: false)
    @agency = agency
    @membership = membership
    @role = role
    assign_command_actors(actor:, actor_identifier:, privileged:)
  end

  def call
    ActiveRecord::Base.transaction do
      with_agency_membership_lock(@agency, @membership) { perform }
    end
  end

  private

  def perform
    role = @role.to_s
    unless AgencyMembership::ROLES.include?(role)
      raise Error.new("That role is not valid.", code: :invalid_role)
    end

    unless @membership.active? || @membership.suspended?
      raise Error.new("Only an accepted membership can change role.", code: :invalid_state)
    end

    previous_role = @membership.role
    return CommandResult.new(status: :accepted, membership: @membership) if previous_role == role

    if previous_role == "administrator" && role != "administrator"
      ensure_not_last_administrator!(@agency, @membership)
    end

    @membership.update!(role: role)
    audit!(
      agency: @agency,
      action: "team.role_changed",
      subject: @membership,
      details: {
        "membership_id" => @membership.id,
        "user_id" => @membership.user_id,
        "previous_role" => previous_role,
        "role" => @membership.role
      },
      **actor_audit_args
    )
    CommandResult.new(status: :accepted, membership: @membership)
  end
end
