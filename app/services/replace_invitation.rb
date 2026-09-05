class ReplaceInvitation < MembershipCommand
  def initialize(agency:, membership:, actor: nil, actor_identifier: nil)
    @agency = agency
    @actor = actor
    @actor_identifier = actor_identifier
    @membership = membership
  end

  def call
    result = nil

    ActiveRecord::Base.transaction do
      result = with_agency_membership_lock(@agency, @membership) { perform }
    end

    enqueue_invitation_mail(result)
    result
  end

  private

  def enqueue_invitation_mail(result)
    return unless result&.enqueue_mail?

    ActiveRecord.after_all_transactions_commit do
      InvitationsMailer.invite(result.membership).deliver_later
    end
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
