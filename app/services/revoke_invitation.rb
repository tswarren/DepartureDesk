class RevokeInvitation < MembershipCommand
  def initialize(agency:, membership:, actor: nil, actor_identifier: nil, privileged: false)
    @agency = agency
    @membership = membership
    assign_command_actors(actor:, actor_identifier:, privileged:)
  end

  def call
    ActiveRecord::Base.transaction do
      with_agency_membership_lock(@agency, @membership) { perform }
    end
  end

  private

  def perform
    unless @membership.invitation_open?
      raise Error.new("Only a pending invitation can be revoked.", code: :invalid_state)
    end

    @membership.update!(
      status: "revoked",
      invitation_version: @membership.invitation_version + 1
    )
    audit!(
      agency: @agency,
      action: "team.invitation_revoked",
      subject: @membership,
      details: {
        "membership_id" => @membership.id,
        "user_id" => @membership.user_id
      },
      **actor_audit_args
    )
    CommandResult.new(status: :revoked, membership: @membership)
  end
end
