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
    ensure_current_office_set_legal!

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

  def ensure_current_office_set_legal!
    if @agency.offices.active.exists?
      if @membership.staff? && !@membership.has_active_office_assignment?
        raise Error.new("This invitation has no operational office.", code: :no_office_access)
      end
      if @membership.administrator? && !@membership.has_active_default_office?
        raise Error.new("This invitation has no default office.", code: :no_office_access)
      end
    elsif @membership.staff?
      raise Error.new("Staff cannot be invited until an office exists.", code: :invalid)
    end
  end
end
