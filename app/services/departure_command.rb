class DepartureCommand < MembershipCommand
  private

  def with_departure_locks(
    agency,
    offices: [],
    program: nil,
    departure: nil,
    parties: [],
    memberships: [],
    team_assignments: [],
    party_role_assignments: [],
    require_administrator: false
  )
    ensure_actor_shape!
    agency.with_lock do
      agency.reload
      Array(offices).compact.uniq.sort_by(&:id).each do |office|
        office.lock!
        office.reload
        ensure_office_belongs_to_agency!(agency, office)
      end
      if program
        program.lock!
        program.reload
        ensure_program_belongs_to_agency!(agency, program)
      end
      if departure
        departure.lock!
        departure.reload
        ensure_departure_belongs_to_agency!(agency, departure)
      end
      Array(parties).compact.uniq.sort_by(&:id).each do |party|
        party.lock!
        party.reload
        ensure_party_belongs_to_agency!(agency, party)
      end
      Array(memberships).compact.uniq.sort_by(&:id).each do |membership|
        membership.lock!
        membership.reload
        ensure_membership_belongs_to_agency!(agency, membership)
      end
      Array(team_assignments).compact.uniq.sort_by(&:id).each do |assignment|
        assignment.lock!
        assignment.reload
        ensure_assignment_belongs_to_agency!(agency, assignment)
      end
      Array(party_role_assignments).compact.uniq.sort_by(&:id).each do |assignment|
        assignment.lock!
        assignment.reload
        ensure_assignment_belongs_to_agency!(agency, assignment)
      end
      if require_administrator
        ensure_tenant_actor!(agency)
      else
        ensure_agency_operator!(agency)
      end
      yield
    end
  end

  def actor_membership(agency)
    membership = @actor&.usable_agency_membership
    return membership if membership && membership.agency_id == agency.id

    raise Error.new(UNAUTHORIZED, code: :unauthorized)
  end

  def ensure_program_belongs_to_agency!(agency, program)
    return if program.agency_id == agency.id

    raise Error.new("That travel program is not part of this agency.", code: :invalid)
  end

  def ensure_departure_belongs_to_agency!(agency, departure)
    return if departure.agency_id == agency.id

    raise Error.new("That departure is not part of this agency.", code: :invalid)
  end

  def ensure_party_belongs_to_agency!(agency, party)
    return if party.agency_id == agency.id

    raise Error.new("That party is not part of this agency.", code: :invalid)
  end

  def ensure_office_access!(membership, office)
    return if membership.can_access_office?(office)

    raise Error.new("That office is not available.", code: :not_found)
  end

  def ensure_active_office!(office)
    return if office.active?

    raise Error.new("Choose an active office.", code: :invalid)
  end

  def ensure_active_program!(program)
    return if program.nil? || program.active?

    raise Error.new("Choose an active travel program.", code: :invalid)
  end

  def ensure_fresh_lock!(record, lock_version)
    return if lock_version.nil?
    return if record.lock_version == lock_version.to_i

    raise ActiveRecord::StaleObjectError.new(record, "update")
  end

  def require_manager_or_administrator!(membership, departure)
    return if membership.administrator?
    current = departure.current_group_manager_assignment
    return if current && current.agency_membership_id == membership.id

    raise Error.new(UNAUTHORIZED, code: :unauthorized)
  end

  def ensure_eligible_team_member!(membership, office)
    unless membership.active?
      raise Error.new("Choose an active team member.", code: :invalid)
    end
    return if membership.can_access_office?(office)

    raise Error.new("That team member cannot access this office.", code: :invalid)
  end

  def known_currency!(code)
    normalized = code.to_s.strip.upcase
    Money::Currency.find(normalized)
    normalized
  rescue Money::Currency::UnknownCurrency
    raise Error.new("Choose a supported currency.", code: :invalid)
  end
end
