class RevokeOfficeAccess < MembershipCommand
  def initialize(agency:, membership:, office:, replacement_office: nil, actor: nil, actor_identifier: nil, privileged: false)
    @agency = agency
    @membership = membership
    @office = office
    @replacement_office = replacement_office
    assign_command_actors(actor:, actor_identifier:, privileged:)
  end

  def call
    affected_office_id = nil

    ActiveRecord::Base.transaction do
      with_agency_office_lock(@agency, office: @office, membership: @membership) do
        perform
        affected_office_id = @office.id
      end
    end

    clear_session_offices_later(affected_office_id)
    CommandResult.new(status: :revoked, office: @office, membership: @membership)
  end

  private

  def perform
    assignment = @membership.office_assignments.find_by(office: @office)
    raise Error.new("That office is not assigned.", code: :invalid_state) unless assignment

    assignment.lock!
    assignment.reload
    ensure_assignment_belongs_to_agency!(@agency, assignment)
    unless assignment.active?
      raise Error.new("That office assignment is already revoked.", code: :invalid_state)
    end
    reject_current_departure_dependency!

    if assignment.is_default?
      remaining = @membership.office_assignments.active.where.not(id: assignment.id)
      if remaining.exists?
        raise Error.new("Choose another default office before revoking this assignment.", code: :invalid) unless @replacement_office

        GrantOfficeAccess.new(
          agency: @agency,
          membership: @membership,
          office: @replacement_office,
          make_default: true,
          actor: @actor,
          actor_identifier: @actor_identifier,
          privileged: @privileged
        ).call
      end
    end

    assignment.revoke!
    audit!(
      agency: @agency,
      action: "office_access.revoked",
      subject: assignment,
      details: {
        "office_id" => @office.id,
        "office_code" => @office.code,
        "membership_id" => @membership.id,
        "user_id" => @membership.user_id
      },
      **actor_audit_args
    )
  end

  def reject_current_departure_dependency!
    return if @membership.administrator?

    scope = DepartureTeamAssignment.current.joins(:departure).where(
      agency_id: @agency.id,
      agency_membership_id: @membership.id,
      departures: { office_id: @office.id, status: Departure::NONTERMINAL_STATUSES }
    ).includes(:departure)
    total = scope.count
    return if total.zero?

    labels = scope.order(:id).limit(5).map { |assignment|
      "#{assignment.departure.departure_reference} #{assignment.departure.name}"
    }
    extra = total - labels.size
    suffix = extra.positive? ? ", and #{extra} more" : ""
    noun = total == 1 ? "departure" : "departures"
    raise Error.new(
      "Reassign #{total} current #{noun} before revoking access to this office: #{labels.join(", ")}#{suffix}.",
      code: :departure_dependency
    )
  end
end
