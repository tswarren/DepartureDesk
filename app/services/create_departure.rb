class CreateDeparture < DepartureCommand
  def initialize(
    agency:,
    office:,
    name:,
    start_date:,
    end_date:,
    creation_idempotency_key:,
    travel_program: nil,
    description: nil,
    client_facing_description: nil,
    primary_destination: nil,
    sales_open_on: nil,
    sales_close_on: nil,
    default_currency: nil,
    group_manager_membership: nil,
    responsible_advisor_membership: nil,
    actor: nil,
    actor_identifier: nil,
    privileged: false
  )
    @agency = agency
    @office = office
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
    @creation_idempotency_key = creation_idempotency_key
    @group_manager_membership = group_manager_membership
    @responsible_advisor_membership = responsible_advisor_membership
    assign_command_actors(actor:, actor_identifier:, privileged:)
  end

  def call
    ActiveRecord::Base.transaction do
      with_departure_locks(
        @agency,
        offices: [ @office ],
        program: @travel_program,
        memberships: selected_memberships
      ) { perform }
    end
  rescue ActiveRecord::RecordInvalid => error
    raise Error.new(error.record.errors.full_messages.to_sentence, code: :invalid)
  end

  private

  def perform
    key = parse_idempotency_key!
    existing = @agency.departures.find_by(creation_idempotency_key: key)
    return replay_existing!(existing) if existing

    actor = actor_membership(@agency)
    ensure_active_office!(@office)
    ensure_office_access!(actor, @office)
    ensure_active_program!(@travel_program)
    manager = @group_manager_membership || actor
    ensure_membership_belongs_to_agency!(@agency, manager)
    ensure_eligible_team_member!(manager, @office)
    if @responsible_advisor_membership
      ensure_membership_belongs_to_agency!(@agency, @responsible_advisor_membership)
      ensure_eligible_team_member!(@responsible_advisor_membership, @office)
    end

    currency = known_currency!(@default_currency.presence || @agency.default_currency)
    now = Time.current
    effective_from = OfficeDate.today(@office)
    reference = AllocateDepartureReference.next!(@agency)

    departure = @agency.departures.create!(
      office: @office,
      owning_office_status: "active",
      travel_program: @travel_program,
      travel_program_status: @travel_program ? "active" : nil,
      departure_reference: reference,
      creation_idempotency_key: key,
      name: @name,
      description: @description,
      client_facing_description: @client_facing_description,
      primary_destination: @primary_destination,
      start_date: @start_date,
      end_date: @end_date,
      sales_open_on: @sales_open_on,
      sales_close_on: @sales_close_on,
      default_currency: currency,
      status: "draft",
      created_by_membership: actor,
      status_changed_at: now,
      status_changed_by_membership: actor
    )

    create_team_assignment_locked!(
      departure:,
      membership: manager,
      role: "group_manager",
      assigned_by: actor,
      effective_from:,
      assigned_at: now
    )
    if @responsible_advisor_membership
      create_team_assignment_locked!(
        departure:,
        membership: @responsible_advisor_membership,
        role: "responsible_advisor",
        assigned_by: actor,
        effective_from:,
        assigned_at: now
      )
    end

    audit!(
      agency: @agency,
      action: "departure.created",
      subject: departure,
      details: {
        "departure_id" => departure.id,
        "departure_reference" => departure.departure_reference,
        "office_id" => departure.office_id,
        "travel_program_id" => departure.travel_program_id,
        "start_date" => departure.start_date.iso8601,
        "end_date" => departure.end_date.iso8601,
        "default_currency" => departure.default_currency,
        "group_manager_membership_id" => manager.id
      },
      **actor_audit_args
    )
    CommandResult.new(status: :created, departure:)
  end

  def replay_existing!(departure)
    unless same_material?(departure)
      raise Error.new("That create request does not match the original departure.", code: :idempotency_conflict)
    end

    CommandResult.new(status: :accepted, departure:)
  end

  def same_material?(departure)
    manager = @group_manager_membership || actor_membership(@agency)
    currency = (@default_currency.presence || @agency.default_currency).to_s.strip.upcase
    departure.office_id == @office.id &&
      departure.travel_program_id == @travel_program&.id &&
      departure.name == @name.to_s.strip &&
      departure.description == @description.to_s.strip.presence &&
      departure.client_facing_description == @client_facing_description.to_s.strip.presence &&
      departure.primary_destination == @primary_destination.to_s.strip.presence &&
      departure.start_date.to_s == @start_date.to_s &&
      departure.end_date.to_s == @end_date.to_s &&
      departure.sales_open_on.to_s == @sales_open_on.to_s &&
      departure.sales_close_on.to_s == @sales_close_on.to_s &&
      departure.default_currency == currency &&
      departure.current_group_manager_assignment&.agency_membership_id == manager.id &&
      departure.current_responsible_advisor_assignment&.agency_membership_id == @responsible_advisor_membership&.id
  end

  def parse_idempotency_key!
    key = @creation_idempotency_key.to_s.strip
    unless key.match?(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i)
      raise Error.new("A creation token is required.", code: :invalid)
    end

    key.downcase
  end

  def selected_memberships
    actor = @actor&.usable_agency_membership
    [
      actor,
      @group_manager_membership,
      @responsible_advisor_membership
    ].compact
  end

  def create_team_assignment_locked!(departure:, membership:, role:, assigned_by:, effective_from:, assigned_at:)
    departure.team_assignments.create!(
      agency: @agency,
      agency_membership: membership,
      membership_status: "active",
      assignment_role: role,
      member_name_snapshot: membership.agency_display_name,
      effective_from:,
      assigned_at:,
      assigned_by_membership: assigned_by
    )
  end
end
