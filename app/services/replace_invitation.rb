class ReplaceInvitation < MembershipCommand
  def initialize(agency:, membership:, actor: nil, actor_identifier: nil, privileged: false)
    @agency = agency
    @membership = membership
    assign_command_actors(actor:, actor_identifier:, privileged:)
  end

  def call
    result = nil

    ActiveRecord::Base.transaction do
      result = with_agency_membership_lock(@agency, @membership) { perform }
      record_delivery_intent(result)
    end

    result
  end

  private

  def record_delivery_intent(result)
    return unless result&.enqueue_mail?

    DeliveryIntent.record!(
      agency: @agency,
      subject: result.membership,
      purpose: "team_invitation",
      version: result.membership.invitation_version
    )
  end

  def perform
    unless @membership.invitation_open? || @membership.revoked?
      raise Error.new("This membership cannot receive a replacement invitation.", code: :invalid_state)
    end

    @membership.update!(
      status: "invited",
      invitation_version: @membership.invitation_version + 1,
      invitation_sent_at: Time.current
    )
    audit!(
      agency: @agency,
      action: "team.invitation_replaced",
      subject: @membership,
      details: {
        "membership_id" => @membership.id,
        "user_id" => @membership.user_id
      },
      **actor_audit_args
    )
    CommandResult.new(status: :replaced, membership: @membership.reload)
  end
end
