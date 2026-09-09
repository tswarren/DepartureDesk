class DeactivateTravelProgram < DepartureCommand
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
  rescue ActiveRecord::InvalidForeignKey, ActiveRecord::StatementInvalid => error
    raise Error.new(dependency_message, code: :program_dependency) if program_status_fk_violation?(error)

    raise
  end

  private

  def perform
    ensure_fresh_lock!(@travel_program, @lock_version)
    return CommandResult.new(status: :accepted, travel_program: @travel_program) if @travel_program.inactive?

    linked = @travel_program.nonterminal_departures.order(:id).lock.to_a
    reject_nonterminal_dependency!(linked)

    actor = actor_membership(@agency)
    @travel_program.update!(
      status: "inactive",
      inactivated_at: Time.current,
      inactivated_by_membership: actor,
      inactivation_reason: @reason
    )
    audit!(
      agency: @agency,
      action: "travel_program.deactivated",
      subject: @travel_program,
      details: {
        "travel_program_id" => @travel_program.id,
        "reason" => @reason
      },
      **actor_audit_args
    )
    CommandResult.new(status: :accepted, travel_program: @travel_program)
  end

  def reject_nonterminal_dependency!(linked)
    return if linked.empty?

    labels = linked.first(5).map { |departure| "#{departure.departure_reference} #{departure.name}" }
    extra = linked.size - labels.size
    suffix = extra.positive? ? ", and #{extra} more" : ""
    noun = linked.size == 1 ? "departure" : "departures"
    raise Error.new(
      "Complete, cancel, or move #{linked.size} linked #{noun} before deactivating this program: #{labels.join(", ")}#{suffix}.",
      code: :program_dependency
    )
  end

  def dependency_message
    linked = @travel_program.nonterminal_departures.order(:id).to_a
    return "Complete, cancel, or move linked departures before deactivating this program." if linked.empty?

    reject_nonterminal_dependency!(linked)
  rescue Error => error
    error.message
  end

  def program_status_fk_violation?(error)
    cause = error.is_a?(ActiveRecord::InvalidForeignKey) ? error : error.cause
    message = [ error.message, cause&.message ].compact.join(" ")
    message.include?("departures_program_active_projection_fk")
  end
end
