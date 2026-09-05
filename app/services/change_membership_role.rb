class ChangeMembershipRole < MembershipCommand
  def initialize(agency:, membership:, role:, actor: nil, actor_identifier: nil)
    @agency = agency
    @actor = actor
    @actor_identifier = actor_identifier
    @membership = membership
    @role = role
  end

  def call
    ActiveRecord::Base.transaction do
      with_agency_membership_lock(@agency, @membership) { perform }
    end
  end

  private

  def perform
    unless @membership.active? || @membership.suspended?
      raise Error.new("Only an accepted membership can change role.", code: :invalid_state)
    end

    previous_role = @membership.role
    return CommandResult.new(status: :accepted, membership: @membership) if previous_role == @role

    if previous_role == "administrator" && @role != "administrator"
      ensure_not_last_administrator!(@agency, @membership)
    end

    @membership.update!(role: @role)
    audit!(
      agency: @agency,
      action: "team.role_changed",
      actor: @actor,
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
