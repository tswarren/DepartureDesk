class CreatePartyNote < DirectoryCommand
  def initialize(agency:, party:, body:, visibility:, actor: nil, actor_identifier: nil, privileged: false, pinned: false)
    @agency = agency
    @party = party
    @body = body.to_s
    @visibility = visibility.to_s
    @pinned = pinned
    assign_command_actors(actor:, actor_identifier:, privileged:)
  end

  def call
    with_directory_locks(@agency, parties: [ @party ]) { perform }
  end

  def call_locked!
    perform
  end

  private

  def perform
    unless PartyNote::VISIBILITIES.include?(@visibility)
      raise Error.new("Choose a note visibility.", code: :invalid)
    end
    ensure_visibility_allowed!(@visibility)
    if (violation = PartyNoteContentPolicy.violation_for(@body))
      raise Error.new(violation, code: :invalid)
    end
    raise Error.new("Enter a note.", code: :invalid) if @body.strip.blank?

    note = @party.notes.create!(
      agency: @agency,
      author_membership: actor_membership!(@agency),
      body: @body.strip,
      visibility: @visibility,
      pinned: @pinned,
      record_status: "active"
    )
    audit!(
      agency: @agency,
      action: "directory.note_created",
      subject: note,
      details: {
        "party_id" => @party.id,
        "note_id" => note.id,
        "visibility" => note.visibility,
        "pinned" => note.pinned
      },
      **actor_audit_args
    )
    CommandResult.new(status: :created, party: @party, note:)
  end

  def ensure_visibility_allowed!(visibility)
    return if visibility == "standard"

    membership = actor_membership!(@agency)
    return if membership.administrator?

    raise Error.new(UNAUTHORIZED, code: :unauthorized)
  end
end
