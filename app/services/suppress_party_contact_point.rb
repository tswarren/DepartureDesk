class SuppressPartyContactPoint < DirectoryCommand
  def initialize(agency:, party:, contact_point:, reason:, actor: nil, actor_identifier: nil, privileged: false)
    @agency = agency
    @party = party
    @contact_point = contact_point
    @reason = reason.to_s.strip
    assign_command_actors(actor:, actor_identifier:, privileged:)
  end

  def call
    with_directory_locks(@agency, parties: [ @party ], records: [ @contact_point ]) { perform }
  end

  private

  def perform
    ensure_contact_point_on_party!(@party, @contact_point)
    return CommandResult.new(status: :accepted, party: @party, contact_point: @contact_point) if @contact_point.suppressed?
    raise Error.new("Enter a reason for marking this contact do not use.", code: :invalid) if @reason.blank?

    @contact_point.update!(
      suppressed_at: Time.current,
      suppressed_by_membership: actor_membership!(@agency),
      suppression_reason: @reason
    )
    audit!(
      agency: @agency,
      action: "directory.contact_suppressed",
      subject: @contact_point,
      details: {
        "party_id" => @party.id,
        "contact_point_id" => @contact_point.id,
        "contact_kind" => @contact_point.contact_kind
      },
      **actor_audit_args
    )
    CommandResult.new(status: :accepted, party: @party, contact_point: @contact_point)
  end
end
