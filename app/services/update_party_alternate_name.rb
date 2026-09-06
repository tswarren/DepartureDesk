class UpdatePartyAlternateName < MembershipCommand
  def initialize(agency:, party:, alternate_name:, name:, name_kind:, actor: nil, actor_identifier: nil, privileged: false)
    @agency = agency
    @party = party
    @alternate_name = alternate_name
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
        @alternate_name.lock!
        @party.reload
        @alternate_name.reload
        ensure_agency_operator!(@agency)
        raise Error.new("That party is not part of this agency.", code: :not_found) unless @party.agency_id == @agency.id
        unless @alternate_name.party_id == @party.id && @alternate_name.agency_id == @agency.id
          raise Error.new("That alternate name is not part of this party.", code: :not_found)
        end
        if @alternate_name.removed?
          raise Error.new("That alternate name has already been removed.", code: :invalid)
        end

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
    before = { "name" => @alternate_name.name, "name_kind" => @alternate_name.name_kind }
    @alternate_name.assign_attributes(name: @name, name_kind: @name_kind)
    unless @alternate_name.has_changes_to_save?
      return CommandResult.new(status: :accepted, party: @party)
    end

    @alternate_name.save!
    audit!(
      agency: @agency,
      action: "directory.alternate_name_updated",
      subject: @alternate_name,
      details: {
        "party_id" => @party.id,
        "alternate_name_id" => @alternate_name.id,
        "before" => before,
        "after" => { "name" => @alternate_name.name, "name_kind" => @alternate_name.name_kind }
      },
      **actor_audit_args
    )
    CommandResult.new(status: :accepted, party: @party)
  end
end
