class RemovePartyNote < DirectoryCommand
  def initialize(agency:, party:, note:, reason:, actor: nil, actor_identifier: nil, privileged: false)
    @agency = agency
    @party = party
    @note = note
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
    return CommandResult.new(status: :accepted, party: @party, note: @note) if @note.record_removed?
    unless @note.record_active?
      raise Error.new("That note cannot be removed.", code: :invalid)
    end
    raise Error.new("Enter a removal reason.", code: :invalid) if @reason.blank?

    membership = actor_membership!(@agency)
    if @note.administrator_only? && !membership.administrator?
      raise Error.new("That note is not part of this party.", code: :not_found)
    end

    @note.update!(
      record_status: "removed",
      removed_at: Time.current,
      removed_by_membership: membership,
      removal_reason: @reason,
      pinned: false
    )
    audit!(
      agency: @agency,
      action: "directory.note_removed",
      subject: @note,
      details: {
        "party_id" => @party.id,
        "note_id" => @note.id,
        "visibility" => @note.visibility
      },
      **actor_audit_args
    )
    CommandResult.new(status: :accepted, party: @party, note: @note)
  end
end
