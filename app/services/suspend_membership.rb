class SuspendMembership < MembershipCommand
  def initialize(agency:, membership:, actor: nil, actor_identifier: nil, privileged: false)
    @agency = agency
    @membership = membership
    assign_command_actors(actor:, actor_identifier:, privileged:)
  end

  def call
    user = nil

    ActiveRecord::Base.transaction do
      with_agency_membership_lock(@agency, @membership) do
        perform
        user = @membership.user
      end
    end

    destroy_sessions_later(user)
    CommandResult.new(status: :accepted, membership: @membership.reload)
  end

  private

  def perform
    unless @membership.active?
      raise Error.new("Only an active membership can be suspended.", code: :invalid_state)
    end

    ensure_not_last_administrator!(@agency, @membership)
    @membership.update!(status: "suspended")
    audit!(
      agency: @agency,
      action: "team.membership_suspended",
      subject: @membership,
      details: {
        "membership_id" => @membership.id,
        "user_id" => @membership.user_id,
        "previous_status" => "active",
        "status" => "suspended"
      },
      **actor_audit_args
    )
  end
end
