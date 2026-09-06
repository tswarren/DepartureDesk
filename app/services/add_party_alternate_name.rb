class AddPartyAlternateName < MembershipCommand
  def initialize(agency:, party:, name:, name_kind:, actor: nil, actor_identifier: nil, privileged: false)
    @agency = agency
    @party = party
    @name = name
    @name_kind = name_kind
    assign_command_actors(actor:, actor_identifier:, privileged:)
  end

  def call
    ActiveRecord::Base.transaction do
      ensure_actor_shape!
      @agency.with_lock do
        @agency.reload
        @party.lock!
        @party.reload
        ensure_agency_operator!(@agency)
        raise Error.new("That party is not part of this agency.", code: :not_found) unless @party.agency_id == @agency.id

        perform
      end
    end
  rescue ActiveRecord::RecordNotUnique
    raise Error.new("That alternate name is already recorded.", code: :conflict)
  rescue ActiveRecord::RecordInvalid => error
    raise Error.new(error.record.errors.full_messages.to_sentence, code: :invalid)
  end

  private

  def perform
    normalized = PartyName.normalize(@name)
    existing = @party.alternate_names.removed
      .where(name_kind: @name_kind, normalized_name: normalized)
      .order(:id)
      .last
    reactivated = false

    if existing
      existing.lock!
      existing.reload
      existing.assign_attributes(
        name: @name,
        status: "active",
        removed_at: nil,
        removed_by_membership: nil
      )
      existing.save!
      alternate = existing
      reactivated = true
    else
      alternate = @party.alternate_names.create!(
        agency: @agency,
        name: @name,
        name_kind: @name_kind,
        status: "active"
      )
    end

    audit!(
      agency: @agency,
      action: "directory.alternate_name_added",
      subject: alternate,
      details: {
        "party_id" => @party.id,
        "alternate_name_id" => alternate.id,
        "name_kind" => alternate.name_kind,
        "reactivated" => reactivated
      },
      **actor_audit_args
    )
    CommandResult.new(status: :created, party: @party)
  end
end
