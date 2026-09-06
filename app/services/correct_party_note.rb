class CorrectPartyNote < DirectoryCommand
  def initialize(agency:, party:, note:, body:, reason:, actor: nil, actor_identifier: nil, privileged: false)
    @agency = agency
    @party = party
    @note = note
    @body = body.to_s
    @reason = reason.to_s.strip
    assign_command_actors(actor:, actor_identifier:, privileged:)
  end

  def call
    with_directory_locks(@agency, parties: [ @party ], records: [ @note ]) { perform }
  end

  private

  def perform
    unless @note.party_id == @party.id && @note.agency_id == @agency.id
      raise Error.new("That note is not part of this party.", code: :not_found)
    end
    unless @note.record_active?
      raise Error.new("That note has already been corrected.", code: :conflict)
    end
    raise Error.new("Enter a correction reason.", code: :invalid) if @reason.blank?
    ensure_can_manage!(@note)
    if (violation = PartyNoteContentPolicy.violation_for(@body))
      raise Error.new(violation, code: :invalid)
    end

    replacement = CreatePartyNote.new(
      agency: @agency,
      party: @party,
      body: @body,
      visibility: @note.visibility,
      pinned: @note.pinned,
      actor: @actor,
      actor_identifier: @actor_identifier,
      privileged: @privileged
    ).call_locked!.note

    @note.update!(
      record_status: "superseded",
      superseded_by_note: replacement,
      corrected_at: Time.current,
      corrected_by_membership: actor_membership!(@agency),
      correction_reason: @reason,
      pinned: false
    )
    audit!(
      agency: @agency,
      action: "directory.note_corrected",
      subject: @note,
      details: {
        "party_id" => @party.id,
        "note_id" => @note.id,
        "replacement_note_id" => replacement.id,
        "visibility" => @note.visibility
      },
      **actor_audit_args
    )
    CommandResult.new(status: :accepted, party: @party, note: replacement)
  end

  def ensure_can_manage!(note)
    membership = actor_membership!(@agency)
    return if note.standard?
    return if membership.administrator?

    raise Error.new("That note is not part of this party.", code: :not_found)
  end
end
