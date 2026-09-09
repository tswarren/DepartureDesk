class UpdateDeparture < DepartureCommand
  EDITABLE = %w[
    name
    description
    client_facing_description
    primary_destination
    start_date
    end_date
    sales_open_on
    sales_close_on
    default_currency
    travel_program_id
  ].freeze

  def initialize(
    agency:,
    departure:,
    name:,
    start_date:,
    end_date:,
    travel_program: nil,
    description: nil,
    client_facing_description: nil,
    primary_destination: nil,
    sales_open_on: nil,
    sales_close_on: nil,
    default_currency: nil,
    lock_version: nil,
    actor: nil,
    actor_identifier: nil,
    privileged: false
  )
    @agency = agency
    @departure = departure
    @travel_program = travel_program
    @name = name
    @description = description
    @client_facing_description = client_facing_description
    @primary_destination = primary_destination
    @start_date = start_date
    @end_date = end_date
    @sales_open_on = sales_open_on
    @sales_close_on = sales_close_on
    @default_currency = default_currency
    @lock_version = lock_version
    assign_command_actors(actor:, actor_identifier:, privileged:)
  end

  def call
    ActiveRecord::Base.transaction do
      with_departure_locks(
        @agency,
        offices: [ @departure.office ],
        program: @travel_program,
        departure: @departure
      ) { perform }
    end
  rescue ActiveRecord::StaleObjectError
    raise Error.new("This departure was updated by someone else.", code: :conflict)
  rescue ActiveRecord::RecordInvalid => error
    raise Error.new(error.record.errors.full_messages.to_sentence, code: :invalid)
  end

  private

  def perform
    actor = actor_membership(@agency)
    ensure_office_access!(actor, @departure.office)
    unless @departure.nonterminal?
      raise Error.new("Only a draft or planning departure can be updated.", code: :invalid_state)
    end
    ensure_fresh_lock!(@departure, @lock_version)
    ensure_active_office!(@departure.office)
    ensure_active_program!(@travel_program)

    before = snapshot
    @departure.assign_attributes(
      name: @name,
      description: @description,
      client_facing_description: @client_facing_description,
      primary_destination: @primary_destination,
      start_date: @start_date,
      end_date: @end_date,
      sales_open_on: @sales_open_on,
      sales_close_on: @sales_close_on,
      default_currency: known_currency!(@default_currency.presence || @departure.default_currency),
      travel_program: @travel_program,
      travel_program_status: @travel_program ? "active" : nil
    )
    return CommandResult.new(status: :accepted, departure: @departure) unless @departure.changed?

    @departure.save!
    after = snapshot
    changed = EDITABLE.select { |field| before[field] != after[field] }
    audit!(
      agency: @agency,
      action: "departure.updated",
      subject: @departure,
      details: {
        "departure_id" => @departure.id,
        "changed_fields" => changed,
        "before" => before.slice(*changed),
        "after" => after.slice(*changed)
      },
      **actor_audit_args
    )
    CommandResult.new(status: :accepted, departure: @departure)
  end

  def snapshot
    {
      "name" => @departure.name,
      "description" => @departure.description,
      "client_facing_description" => @departure.client_facing_description,
      "primary_destination" => @departure.primary_destination,
      "start_date" => @departure.start_date&.iso8601,
      "end_date" => @departure.end_date&.iso8601,
      "sales_open_on" => @departure.sales_open_on&.iso8601,
      "sales_close_on" => @departure.sales_close_on&.iso8601,
      "default_currency" => @departure.default_currency,
      "travel_program_id" => @departure.travel_program_id
    }
  end
end
