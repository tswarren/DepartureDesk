class SetContactPointPrimary < DirectoryCommand
  def initialize(agency:, party:, contact_point:, purpose:, actor: nil, actor_identifier: nil, privileged: false, effective_from: nil)
    @agency = agency
    @party = party
    @contact_point = contact_point
    @purpose = purpose.to_s
    @effective_from = effective_from
    assign_command_actors(actor:, actor_identifier:, privileged:)
  end

  def call
    with_directory_locks(@agency, parties: [ @party ], records: [ @contact_point ]) do
      overlapping = overlapping_primaries
      overlapping.sort_by { |row| row.id.to_s }.each do |row|
        row.lock!
        row.reload
      end
      perform(overlapping)
    end
  end

  private

  def perform(overlapping)
    ensure_contact_point_on_party!(@party, @contact_point)
    unless ContactPointPurposeAssignment::PURPOSES.include?(@purpose)
      raise Error.new("Choose a contact purpose.", code: :invalid)
    end
    unless @contact_point.eligible_destination?
      raise Error.new("That contact point cannot be used as a destination.", code: :invalid)
    end

    from = @effective_from.presence || DirectoryDate.today(@agency)
    actor = actor_membership!(@agency)
    current_primary = overlapping.find { |assignment| assignment.contact_point_id == @contact_point.id }
    others = overlapping.reject { |assignment| assignment.contact_point_id == @contact_point.id }
    to_supersede = []

    others.each do |assignment|
      if assignment.effective_from.blank? || assignment.effective_from < from
        assignment.update!(
          effective_until: from,
          ended_at: Time.current,
          ended_by_membership: actor,
          ending_reason: "Replaced as primary"
        )
      else
        to_supersede << assignment
      end
    end

    if current_primary && to_supersede.empty?
      return CommandResult.new(status: :accepted, party: @party, contact_point: @contact_point, purpose_assignment: current_primary)
    end

    replacement = if current_primary
      current_primary
    else
      AssignContactPointPurpose.new(
        agency: @agency,
        party: @party,
        contact_point: @contact_point,
        purpose: @purpose,
        priority: to_supersede.any? ? 2 : 1,
        effective_from: from,
        actor: @actor,
        actor_identifier: @actor_identifier,
        privileged: @privileged
      ).call_locked!.purpose_assignment
    end

    to_supersede.each do |assignment|
      assignment.update!(
        record_status: "superseded",
        superseded_by_assignment: replacement,
        corrected_at: Time.current,
        corrected_by_membership: actor,
        correction_reason: "Replaced as primary"
      )
    end

    replacement.update!(priority: 1) if replacement.priority != 1
    CommandResult.new(status: :accepted, party: @party, contact_point: @contact_point, purpose_assignment: replacement)
  end

  def overlapping_primaries
    from = @effective_from.presence || DirectoryDate.today(@agency)
    ContactPointPurposeAssignment
      .where(
        agency_id: @agency.id,
        party_id: @party.id,
        contact_kind: @contact_point.contact_kind,
        purpose: @purpose,
        record_status: "valid",
        priority: 1
      )
      .where("daterange(effective_from, effective_until, '[)') && daterange(?::date, NULL, '[)')", from)
      .to_a
  end
end
