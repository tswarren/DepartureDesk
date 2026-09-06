class ReactivatePartyContactPoint < DirectoryCommand
  def initialize(agency:, party:, contact_point:, actor: nil, actor_identifier: nil, privileged: false)
    @agency = agency
    @party = party
    @contact_point = contact_point
    assign_command_actors(actor:, actor_identifier:, privileged:)
  end

  def call
    with_directory_locks(@agency, parties: [ @party ], records: [ @contact_point ]) { perform }
  end

  private

  def perform
    ensure_contact_point_on_party!(@party, @contact_point)
    return CommandResult.new(status: :accepted, party: @party, contact_point: @contact_point) if @contact_point.active?

    duplicate = @party.contact_points.active.find_by(
      contact_kind: @contact_point.contact_kind,
      normalized_value: @contact_point.normalized_value
    )
    if duplicate && duplicate.id != @contact_point.id
      raise Error.new("That contact information is already recorded.", code: :conflict)
    end

    @contact_point.update!(
      status: "active",
      deactivated_at: nil,
      deactivated_by_membership: nil,
      deactivation_reason: nil
    )
    audit!(
      agency: @agency,
      action: "directory.contact_reactivated",
      subject: @contact_point,
      details: {
        "party_id" => @party.id,
        "contact_point_id" => @contact_point.id,
        "contact_kind" => @contact_point.contact_kind,
        "reactivated" => true
      },
      **actor_audit_args
    )
    CommandResult.new(status: :accepted, party: @party, contact_point: @contact_point)
  end
end
