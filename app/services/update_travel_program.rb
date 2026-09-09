class UpdateTravelProgram < DepartureCommand
  def initialize(agency:, travel_program:, name:, description: nil, client_facing_description: nil, lock_version: nil, actor: nil, actor_identifier: nil, privileged: false)
    @agency = agency
    @travel_program = travel_program
    @name = name
    @description = description
    @client_facing_description = client_facing_description
    @lock_version = lock_version
    assign_command_actors(actor:, actor_identifier:, privileged:)
  end

  def call
    ActiveRecord::Base.transaction do
      with_departure_locks(@agency, program: @travel_program) { perform }
    end
  rescue ActiveRecord::StaleObjectError
    raise Error.new("This travel program was updated by someone else.", code: :conflict)
  end

  private

  def perform
    ensure_fresh_lock!(@travel_program, @lock_version)
    before = snapshot
    @travel_program.assign_attributes(
      name: @name,
      description: @description,
      client_facing_description: @client_facing_description
    )
    return CommandResult.new(status: :accepted, travel_program: @travel_program) unless @travel_program.changed?

    @travel_program.save!
    after = snapshot
    changed = before.keys.select { |field| before[field] != after[field] }
    audit!(
      agency: @agency,
      action: "travel_program.updated",
      subject: @travel_program,
      details: {
        "travel_program_id" => @travel_program.id,
        "changed_fields" => changed,
        "before" => before.slice(*changed),
        "after" => after.slice(*changed)
      },
      **actor_audit_args
    )
    CommandResult.new(status: :accepted, travel_program: @travel_program)
  rescue ActiveRecord::RecordInvalid => error
    raise Error.new(error.record.errors.full_messages.to_sentence, code: :invalid)
  end

  def snapshot
    {
      "name" => @travel_program.name,
      "description" => @travel_program.description,
      "client_facing_description" => @travel_program.client_facing_description
    }
  end
end
