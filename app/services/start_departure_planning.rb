class StartDeparturePlanning < DepartureCommand
  def initialize(agency:, departure:, lock_version: nil, actor: nil, actor_identifier: nil, privileged: false)
    @agency = agency
    @departure = departure
    @lock_version = lock_version
    assign_command_actors(actor:, actor_identifier:, privileged:)
  end

  def call
    ActiveRecord::Base.transaction do
      with_departure_locks(
        @agency,
        offices: [ @departure.office ],
        program: @departure.travel_program,
        departure: @departure,
        memberships: [ @departure.current_group_manager_assignment&.agency_membership ].compact,
        team_assignments: [ @departure.current_group_manager_assignment ].compact
      ) { perform }
    end
  rescue ActiveRecord::StaleObjectError
    raise Error.new("This departure was updated by someone else.", code: :conflict)
  end

  private

  def perform
    actor = actor_membership(@agency)
    ensure_office_access!(actor, @departure.office)
    ensure_fresh_lock!(@departure, @lock_version)
    ensure_active_office!(@departure.office)
    unless @departure.draft?
      raise Error.new("Only a draft departure can start planning.", code: :invalid_state)
    end
    unless @departure.current_group_manager_assignment
      raise Error.new("A group manager is required before planning can start.", code: :invalid_state)
    end

    @departure.update!(
      status: "planning",
      status_changed_at: Time.current,
      status_changed_by_membership: actor
    )
    audit!(
      agency: @agency,
      action: "departure.planning_started",
      subject: @departure,
      details: {
        "departure_id" => @departure.id,
        "previous_status" => "draft",
        "status" => "planning"
      },
      **actor_audit_args
    )
    CommandResult.new(status: :accepted, departure: @departure)
  end
end
