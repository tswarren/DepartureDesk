class SetPartyNotePinned < DirectoryCommand
  def initialize(agency:, party:, note:, pinned:, actor: nil, actor_identifier: nil, privileged: false)
    @agency = agency
    @party = party
    @note = note
    @pinned = pinned
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
      raise Error.new("Only an active note can be pinned.", code: :invalid)
    end

    membership = actor_membership!(@agency)
    if @note.administrator_only? && !membership.administrator?
      raise Error.new("That note is not part of this party.", code: :not_found)
    end

    @note.update!(pinned: @pinned)
    audit!(
      agency: @agency,
      action: "directory.note_pin_changed",
      subject: @note,
      details: {
        "party_id" => @party.id,
        "note_id" => @note.id,
        "pinned" => @note.pinned
      },
      **actor_audit_args
    )
    CommandResult.new(status: :accepted, party: @party, note: @note)
  end
end
