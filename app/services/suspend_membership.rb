class SuspendMembership < MembershipCommand
  ADVISOR_DEPENDENCY_SAMPLE = 5

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
  rescue ActiveRecord::InvalidForeignKey, ActiveRecord::StatementInvalid => error
    raise Error.new(advisor_dependency_message, code: :advisor_dependency) if advisor_status_fk_violation?(error)

    raise
  end

  private

  def perform
    unless @membership.active?
      raise Error.new("Only an active membership can be suspended.", code: :invalid_state)
    end

    ensure_not_last_administrator!(@agency, @membership)
    reject_current_advisor_dependency!

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

  def reject_current_advisor_dependency!
    summary = dependent_advisor_summary
    return if summary[:total].zero?

    raise Error.new(advisor_dependency_message(summary), code: :advisor_dependency)
  end

  def dependent_advisor_summary
    scope = ClientProfile.includes(:party).where(
      agency_id: @agency.id,
      primary_advisor_membership_id: @membership.id,
      status: "active"
    )
    labels = scope.order(:id).limit(ADVISOR_DEPENDENCY_SAMPLE).map { |profile|
      profile.party.display_name
    }
    { total: scope.count, labels: }
  end

  def advisor_dependency_message(summary = nil)
    summary ||= dependent_advisor_summary
    total = summary[:total].to_i
    labels = Array(summary[:labels])
    return "Reassign current client advisors before suspending this membership." if total.zero?

    noun = total == 1 ? "client" : "clients"
    listed = labels.join(", ")
    extra = total - labels.size
    suffix = extra.positive? ? ", and #{extra} more" : ""
    "Reassign #{total} current #{noun} before suspending this membership: #{listed}#{suffix}."
  end

  def advisor_status_fk_violation?(error)
    cause = error.is_a?(ActiveRecord::InvalidForeignKey) ? error : error.cause
    message = [ error.message, cause&.message ].compact.join(" ")
    message.include?("advisor_active_projection_fk")
  end
end
