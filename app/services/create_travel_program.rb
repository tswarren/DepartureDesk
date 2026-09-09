class CreateTravelProgram < DepartureCommand
  def initialize(agency:, name:, description: nil, client_facing_description: nil, actor: nil, actor_identifier: nil, privileged: false)
    @agency = agency
    @name = name
    @description = description
    @client_facing_description = client_facing_description
    assign_command_actors(actor:, actor_identifier:, privileged:)
  end

  def call
    ActiveRecord::Base.transaction do
      with_departure_locks(@agency) { perform }
    end
  end

  private

  def perform
    program = @agency.travel_programs.create!(
      name: @name,
      description: @description,
      client_facing_description: @client_facing_description,
      status: "active"
    )
    audit!(
      agency: @agency,
      action: "travel_program.created",
      subject: program,
      details: {
        "travel_program_id" => program.id,
        "name" => program.name
      },
      **actor_audit_args
    )
    CommandResult.new(status: :created, travel_program: program)
  rescue ActiveRecord::RecordInvalid => error
    raise Error.new(error.record.errors.full_messages.to_sentence, code: :invalid)
  end
end
