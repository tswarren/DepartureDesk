class UpdateClientProfile < UpdateRoleProfile
  def initialize(agency:, party:, profile:, office: nil, lock_version: nil, communication_preference: nil, servicing_restrictions: :omit, billing_restrictions: :omit, actor: nil, actor_identifier: nil, privileged: false)
    @agency = agency
    @party = party
    @profile = profile
    @office = office
    @lock_version = lock_version
    @communication_preference = communication_preference
    @servicing_restrictions = servicing_restrictions
    @billing_restrictions = billing_restrictions
    assign_command_actors(actor:, actor_identifier:, privileged:)
  end

  private

  def profile_association
    :client_profile
  end

  def role_noun
    "client"
  end

  def perform
    ensure_profile_on_party!(@party, @profile)
    unless @profile.active?
      raise Error.new("Inactive roles cannot be updated until they are reactivated.", code: :invalid)
    end

    lock_offices!(@agency, [ @profile.responsible_office, @office ].compact)
    ensure_office_currently_active!(@office) if @office
    ensure_fresh_lock!(@profile, @lock_version)

    changes = guidance_attributes
    office_changed = @office && @profile.responsible_office_id != @office.id
    if office_changed
      changes[:responsible_office] = @office
      changes[:responsible_office_status] = "active"
    end

    return profile_result(:accepted, @party, @profile) if changes.empty?

    previous_office_id = @profile.responsible_office_id
    @profile.update!(changes)
    extra = { "changed_fields" => changes.keys.map(&:to_s) }
    extra["previous_responsible_office_id"] = previous_office_id if office_changed
    audit_profile!(@profile, "directory.client_profile_updated", extra)
    profile_result(:accepted, @party, @profile)
  end

  def guidance_attributes
    attributes = {}
    if @communication_preference.present? && @communication_preference != @profile.communication_preference
      attributes[:communication_preference] = @communication_preference
    end
    unless @servicing_restrictions == :omit
      value = @servicing_restrictions.to_s.strip.presence
      attributes[:servicing_restrictions] = value unless value == @profile.servicing_restrictions
    end
    unless @billing_restrictions == :omit
      value = @billing_restrictions.to_s.strip.presence
      attributes[:billing_restrictions] = value unless value == @profile.billing_restrictions
    end
    attributes
  end
end
