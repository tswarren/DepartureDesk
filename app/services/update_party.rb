class UpdateParty < MembershipCommand
  def initialize(agency:, party:, attributes:, party_lock_version:, profile_lock_version:,
    actor: nil, actor_identifier: nil, privileged: false)
    @agency = agency
    @party = party
    @attributes = attributes.to_h.symbolize_keys
    @party_lock_version = party_lock_version
    @profile_lock_version = profile_lock_version
    assign_command_actors(actor:, actor_identifier:, privileged:)
  end

  def call
    ActiveRecord::Base.transaction do
      ensure_actor_shape!
      @agency.with_lock do
        @agency.reload
        @party.lock!
        @party.reload
        profile = @party.kind_profile
        raise Error.new("That party is not part of this agency.", code: :not_found) unless @party.agency_id == @agency.id

        profile.lock!
        profile.reload
        ensure_agency_operator!(@agency)
        perform(profile)
      end
    end
  rescue ActiveRecord::StaleObjectError
    raise Error.new("This record was updated by someone else.", code: :conflict)
  rescue ActiveRecord::RecordInvalid => error
    raise Error.new(error.record.errors.full_messages.to_sentence, code: :invalid)
  end

  private

  def perform(profile)
    if @party_lock_version && @party.lock_version != @party_lock_version.to_i
      raise ActiveRecord::StaleObjectError.new(@party, "update")
    end
    if @profile_lock_version && profile.lock_version != @profile_lock_version.to_i
      raise ActiveRecord::StaleObjectError.new(profile, "update")
    end

    allowed = CreateParty::PROFILE_ATTRS.fetch(@party.party_kind)
    sensitive = %w[date_of_birth]
    before = profile.attributes.slice(*allowed.map(&:to_s)).except(*sensitive)
    profile.assign_attributes(@attributes.slice(*allowed))
    @party.apply_derived_names!(profile)

    unless profile.has_changes_to_save? || @party.has_changes_to_save?
      return CommandResult.new(status: :accepted, party: @party)
    end

    profile.save!
    @party.save!

    after = profile.reload.attributes.slice(*allowed.map(&:to_s)).except(*sensitive)
    changed = before.keys.select { |field| before[field] != after[field] }
    audit!(
      agency: @agency,
      action: "directory.party_updated",
      subject: @party,
      details: {
        "party_id" => @party.id,
        "party_kind" => @party.party_kind,
        "changed_fields" => changed,
        "before" => before.slice(*changed),
        "after" => after.slice(*changed)
      },
      **actor_audit_args
    )
    CommandResult.new(status: :accepted, party: @party)
  end
end
