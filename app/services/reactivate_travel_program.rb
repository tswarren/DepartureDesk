class ReactivateTravelProgram < DepartureCommand
  def initialize(agency:, travel_program:, reason:, lock_version: nil, actor: nil, actor_identifier: nil, privileged: false)
    @agency = agency
    @travel_program = travel_program
    @reason = reason.to_s.strip
    @lock_version = lock_version
    assign_command_actors(actor:, actor_identifier:, privileged:)
  end

  def call
    raise Error.new("A reason is required.", code: :invalid) if @reason.blank?

    ActiveRecord::Base.transaction do
      with_departure_locks(@agency, program: @travel_program, require_administrator: true) { perform }
    end
  rescue ActiveRecord::StaleObjectError
    raise Error.new("This travel program was updated by someone else.", code: :conflict)
  end

  private

  def perform
    ensure_fresh_lock!(@travel_program, @lock_version)
    return CommandResult.new(status: :accepted, travel_program: @travel_program) if @travel_program.active?

    @travel_program.update!(
      status: "active",
      inactivated_at: nil,
      inactivated_by_membership: nil,
      inactivation_reason: nil
    )
    audit!(
      agency: @agency,
      action: "travel_program.reactivated",
      subject: @travel_program,
      details: {
        "travel_program_id" => @travel_program.id,
        "reason" => @reason
      },
      **actor_audit_args
    )
    CommandResult.new(status: :accepted, travel_program: @travel_program)
  end
end
