class RoleProfileCommand < DirectoryCommand
  private

  def ensure_profile_on_party!(party, profile)
    return if profile.party_id == party.id && profile.agency_id == party.agency_id

    raise Error.new("That role is not part of this party.", code: :not_found)
  end

  def ensure_party_can_hold_active_role!(party)
    return if party.active?

    raise Error.new("An inactive party cannot receive an active role.", code: :invalid)
  end

  def ensure_office_currently_active!(office)
    return if office.active?

    raise Error.new("Choose an active office.", code: :invalid)
  end

  def ensure_fresh_lock!(record, lock_version)
    return if lock_version.nil?
    return if record.lock_version == lock_version.to_i

    raise ActiveRecord::StaleObjectError.new(record, "update")
  end

  def existing_profile_for(party)
    party.public_send(profile_association)
  end

  def profile_result(status, party, profile)
    CommandResult.new(status:, party:, **{ profile_association => profile })
  end

  def audit_profile!(profile, action, extra = {})
    audit!(
      agency: @agency,
      action:,
      subject: profile,
      details: {
        "party_id" => profile.party_id,
        "#{role_noun}_profile_id" => profile.id,
        "status" => profile.status,
        "responsible_office_id" => profile.responsible_office_id
      }.merge(extra),
      **actor_audit_args
    )
  end
end
