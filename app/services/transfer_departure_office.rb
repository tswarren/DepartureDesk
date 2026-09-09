class TransferDepartureOffice < DepartureCommand
  def initialize(agency:, departure:, office:, lock_version: nil, actor: nil, actor_identifier: nil, privileged: false)
    @agency = agency
    @departure = departure
    @office = office
    @lock_version = lock_version
    assign_command_actors(actor:, actor_identifier:, privileged:)
  end

  def call
    ActiveRecord::Base.transaction do
      assignees = @departure.team_assignments.current.includes(:agency_membership).map(&:agency_membership)
      with_departure_locks(
        @agency,
        offices: [ @departure.office, @office ],
        program: @departure.travel_program,
        departure: @departure,
        memberships: assignees,
        require_administrator: true
      ) { perform }
    end
  rescue ActiveRecord::StaleObjectError
    raise Error.new("This departure was updated by someone else.", code: :conflict)
  rescue ActiveRecord::RecordInvalid => error
    raise Error.new(error.record.errors.full_messages.to_sentence, code: :invalid)
  end

  private

  def perform
    ensure_fresh_lock!(@departure, @lock_version)
    unless @departure.nonterminal?
      raise Error.new("Only a draft or planning departure can change offices.", code: :invalid_state)
    end
    ensure_active_office!(@office)
    return CommandResult.new(status: :accepted, departure: @departure) if @office.id == @departure.office_id

    if @departure.supplier_arrangements.exists?
      raise Error.new("This departure already has supplier planning and cannot change offices.", code: :office_transfer_frozen)
    end

    inaccessible = @departure.team_assignments.current.includes(:agency_membership).filter_map { |assignment|
      membership = assignment.agency_membership
      next if membership.can_access_office?(@office)

      membership.agency_display_name
    }
    if inaccessible.any?
      raise Error.new(
        "Reassign team members before transferring this departure: #{inaccessible.join(", ")}.",
        code: :office_access_dependency
      )
    end

    old_office = @departure.office
    @departure.update!(
      office: @office,
      owning_office_status: "active"
    )
    audit!(
      agency: @agency,
      action: "departure.office_transferred",
      subject: @departure,
      details: {
        "departure_id" => @departure.id,
        "from_office_id" => old_office.id,
        "from_office_code" => old_office.code,
        "to_office_id" => @office.id,
        "to_office_code" => @office.code
      },
      **actor_audit_args
    )
    CommandResult.new(status: :accepted, departure: @departure)
  end
end
