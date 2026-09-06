class RemovePartyAlternateName < MembershipCommand
  def initialize(agency:, party:, alternate_name:, actor: nil, actor_identifier: nil, privileged: false)
    @agency = agency
    @party = party
    @alternate_name = alternate_name
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

        perform
      end
    end
  end

  private

  def perform
    return CommandResult.new(status: :accepted, party: @party) if @alternate_name.removed?

    @alternate_name.update!(status: "removed")
    audit!(
      agency: @agency,
      action: "directory.alternate_name_removed",
      subject: @alternate_name,
      details: {
        "party_id" => @party.id,
        "alternate_name_id" => @alternate_name.id,
        "name_kind" => @alternate_name.name_kind
      },
      **actor_audit_args
    )
    CommandResult.new(status: :accepted, party: @party)
  end
end
