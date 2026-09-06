class AssignContactPointPurpose < DirectoryCommand
  def initialize(agency:, party:, contact_point:, purpose:, priority:, actor: nil, actor_identifier: nil, privileged: false, effective_from: nil, effective_until: nil)
    @agency = agency
    @party = party
    @contact_point = contact_point
    @purpose = purpose.to_s
    @priority = priority.to_i
    @effective_from = effective_from
    @effective_until = effective_until
    assign_command_actors(actor:, actor_identifier:, privileged:)
  end

  def call
    with_directory_locks(@agency, parties: [ @party ], records: [ @contact_point ]) { perform }
  end

  def call_locked!
    perform
  end

  private

  def perform
    ensure_contact_point_on_party!(@party, @contact_point)
    unless ContactPointPurposeAssignment::PURPOSES.include?(@purpose)
      raise Error.new("Choose a contact purpose.", code: :invalid)
    end
    raise Error.new("Priority must be a positive integer.", code: :invalid) if @priority < 1
    unless @contact_point.eligible_destination?
      raise Error.new("That contact point cannot be used as a destination.", code: :invalid)
    end

    from = @effective_from.presence || DirectoryDate.today(@agency)
    until_date = @effective_until
    if until_date.present? && until_date <= from
      raise Error.new("The end date must be after the start date.", code: :invalid)
    end

    if @priority == 1 && overlapping_primary?(from, until_date)
      raise Error.new("A primary contact is already assigned for that purpose. Set as primary to replace it.", code: :conflict)
    end

    assignment = ContactPointPurposeAssignment.create!(
      agency: @agency,
      party: @party,
      contact_point: @contact_point,
      contact_kind: @contact_point.contact_kind,
      purpose: @purpose,
      priority: @priority,
      effective_from: from,
      effective_until: until_date,
      record_status: "valid"
    )
    audit!(
      agency: @agency,
      action: "directory.contact_purpose_assigned",
      subject: assignment,
      details: {
        "party_id" => @party.id,
        "contact_point_id" => @contact_point.id,
        "assignment_id" => assignment.id,
        "contact_kind" => @contact_point.contact_kind,
        "purpose" => assignment.purpose,
        "priority" => assignment.priority
      },
      **actor_audit_args
    )
    CommandResult.new(status: :created, party: @party, contact_point: @contact_point, purpose_assignment: assignment)
  end

  def overlapping_primary?(from, until_date)
    ContactPointPurposeAssignment
      .where(
        agency_id: @agency.id,
        party_id: @party.id,
        contact_kind: @contact_point.contact_kind,
        purpose: @purpose,
        record_status: "valid",
        priority: 1
      )
      .where("daterange(effective_from, effective_until, '[)') && daterange(?::date, ?::date, '[)')", from, until_date)
      .exists?
  end
end
