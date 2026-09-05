class ReactivateMembership < MembershipCommand
  def initialize(agency:, membership:, actor: nil, actor_identifier: nil)
    @agency = agency
    @actor = actor
    @actor_identifier = actor_identifier
    @membership = membership
  end

  def call
    ActiveRecord::Base.transaction do
      with_agency_membership_lock(@agency, @membership) { perform }
    end
  end

  private

  def perform
    unless @membership.suspended?
      raise Error.new("Only a suspended membership can be reactivated.", code: :invalid_state)
    end

    if @membership.user.active_agency_memberships.where.not(id: @membership.id).exists?
      raise Error.new("This person cannot be reactivated while they have another active membership.", code: :conflict)
    end

    @membership.update!(status: "active")
    audit!(
      agency: @agency,
      action: "team.membership_reactivated",
      actor: @actor,
      subject: @membership,
      details: {
        "membership_id" => @membership.id,
        "user_id" => @membership.user_id,
        "previous_status" => "suspended",
        "status" => "active"
      },
      **actor_audit_args
    )
    CommandResult.new(status: :accepted, membership: @membership)
  end
end
