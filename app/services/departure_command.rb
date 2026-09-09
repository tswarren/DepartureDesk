class DepartureCommand < MembershipCommand
  private

  def with_departure_locks(
    agency,
    offices: [],
    program: nil,
    departure: nil,
    supplier_arrangements: [],
    supplier_reservations: [],
    supplier_resources: [],
    supplier_service_occurrences: [],
    supplier_confirmations: [],
    supplier_cost_terms: [],
    supplier_commitments: [],
    supplier_deposit_requirements: [],
    supplier_deadlines: [],
    supplier_capacity_positions: [],
    supplier_capacity_events: [],
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
      Array(supplier_arrangements).compact.uniq.sort_by(&:id).each do |arrangement|
        arrangement.lock!
        arrangement.reload
        ensure_supplier_arrangement_belongs_to_agency!(agency, arrangement)
      end
      Array(supplier_reservations).compact.uniq.sort_by(&:id).each do |reservation|
        reservation.lock!
        reservation.reload
        ensure_supplier_reservation_belongs_to_agency!(agency, reservation)
      end
      Array(supplier_resources).compact.uniq.sort_by(&:id).each do |resource|
        resource.lock!
        resource.reload
        ensure_supplier_resource_belongs_to_agency!(agency, resource)
      end
      Array(supplier_service_occurrences).compact.uniq.sort_by(&:id).each do |occurrence|
        occurrence.lock!
        occurrence.reload
        ensure_supplier_service_occurrence_belongs_to_agency!(agency, occurrence)
      end
      Array(supplier_confirmations).compact.uniq.sort_by(&:id).each do |confirmation|
        confirmation.lock!
        confirmation.reload
        ensure_supplier_confirmation_belongs_to_agency!(agency, confirmation)
      end
      Array(supplier_cost_terms).compact.uniq.sort_by(&:id).each do |term|
        term.lock!
        term.reload
        ensure_supplier_cost_term_belongs_to_agency!(agency, term)
      end
      Array(supplier_commitments).compact.uniq.sort_by(&:id).each do |commitment|
        commitment.lock!
        commitment.reload
        ensure_supplier_commitment_belongs_to_agency!(agency, commitment)
      end
      Array(supplier_deposit_requirements).compact.uniq.sort_by(&:id).each do |deposit|
        deposit.lock!
        deposit.reload
        ensure_supplier_deposit_requirement_belongs_to_agency!(agency, deposit)
      end
      Array(supplier_deadlines).compact.uniq.sort_by(&:id).each do |deadline|
        deadline.lock!
        deadline.reload
        ensure_supplier_deadline_belongs_to_agency!(agency, deadline)
      end
      Array(supplier_capacity_positions).compact.uniq.sort_by(&:id).each do |position|
        position.lock!
        position.reload
        ensure_supplier_capacity_position_belongs_to_agency!(agency, position)
      end
      Array(supplier_capacity_events).compact.uniq.sort_by(&:id).each do |event|
        event.lock!
        event.reload
        ensure_supplier_capacity_event_belongs_to_agency!(agency, event)
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

  def ensure_supplier_arrangement_belongs_to_agency!(agency, arrangement)
    return if arrangement.agency_id == agency.id

    raise Error.new("That supplier arrangement is not part of this agency.", code: :invalid)
  end

  def ensure_supplier_reservation_belongs_to_agency!(agency, reservation)
    return if reservation.agency_id == agency.id

    raise Error.new("That supplier reservation is not part of this agency.", code: :invalid)
  end

  def ensure_supplier_resource_belongs_to_agency!(agency, resource)
    return if resource.agency_id == agency.id

    raise Error.new("That supplier resource is not part of this agency.", code: :invalid)
  end

  def ensure_supplier_service_occurrence_belongs_to_agency!(agency, occurrence)
    return if occurrence.agency_id == agency.id

    raise Error.new("That supplier service occurrence is not part of this agency.", code: :invalid)
  end

  def ensure_supplier_confirmation_belongs_to_agency!(agency, confirmation)
    return if confirmation.agency_id == agency.id

    raise Error.new("That supplier confirmation is not part of this agency.", code: :invalid)
  end

  def ensure_supplier_cost_term_belongs_to_agency!(agency, term)
    return if term.agency_id == agency.id

    raise Error.new("That supplier cost term is not part of this agency.", code: :invalid)
  end

  def ensure_supplier_commitment_belongs_to_agency!(agency, commitment)
    return if commitment.agency_id == agency.id

    raise Error.new("That supplier commitment is not part of this agency.", code: :invalid)
  end

  def ensure_supplier_deposit_requirement_belongs_to_agency!(agency, deposit)
    return if deposit.agency_id == agency.id

    raise Error.new("That supplier deposit requirement is not part of this agency.", code: :invalid)
  end

  def ensure_supplier_deadline_belongs_to_agency!(agency, deadline)
    return if deadline.agency_id == agency.id

    raise Error.new("That supplier deadline is not part of this agency.", code: :invalid)
  end

  def ensure_supplier_capacity_position_belongs_to_agency!(agency, position)
    return if position.agency_id == agency.id

    raise Error.new("That supplier capacity position is not part of this agency.", code: :invalid)
  end

  def ensure_supplier_capacity_event_belongs_to_agency!(agency, event)
    return if event.agency_id == agency.id

    raise Error.new("That supplier capacity event is not part of this agency.", code: :invalid)
  end

  def ensure_active_supplier_party!(party)
    return if party&.active? && party.supplier_profile&.active?

    raise Error.new("Choose an active supplier.", code: :invalid)
  end

  def ensure_active_same_agency_party!(party)
    return if party&.active?

    raise Error.new("Choose an active party.", code: :invalid)
  end

  def ensure_departure_can_receive_supplier_planning!(departure)
    unless departure.nonterminal?
      raise Error.new("Supplier planning can only be added to a draft or planning departure.", code: :invalid_state)
    end
    ensure_active_office!(departure.office)
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

  def overlapping_party_role_interval_violation?(error)
    cause = error.cause
    message = [ error.message, cause&.message ].compact.join(" ")
    cause.is_a?(PG::ExclusionViolation) && message.include?("dpra_no_overlapping_intervals")
  end
end
