class DirectoryCommand < MembershipCommand
  private

  def with_directory_locks(agency, parties: [], records: [], offices: [], memberships: [])
    ActiveRecord::Base.transaction do
      ensure_actor_shape!
      agency.with_lock do
        agency.reload
        Array(parties).compact.uniq.sort_by { |party| party.id.to_s }.each do |party|
          party.lock!
          party.reload
          unless party.agency_id == agency.id
            raise Error.new("That party is not part of this agency.", code: :not_found)
          end
        end
        Array(records).compact.uniq.sort_by { |record| [ record.class.name, record.id.to_s ] }.each do |record|
          record.lock!
          record.reload
        end
        lock_offices!(agency, offices)
        lock_memberships!(agency, memberships)
        ensure_agency_operator!(agency)
        yield
      end
    end
  rescue ActiveRecord::RecordNotUnique
    raise Error.new("That directory record already exists.", code: :conflict)
  rescue ActiveRecord::StaleObjectError
    raise Error.new("This record was updated by someone else.", code: :conflict)
  rescue ActiveRecord::InvalidForeignKey, ActiveRecord::StatementInvalid => error
    raise Error.new("Choose an active office.", code: :invalid) if office_status_fk_violation?(error)
    raise Error.new("An inactive party cannot receive an active role.", code: :invalid) if party_status_fk_violation?(error)
    raise Error.new("Choose an active team member as advisor.", code: :invalid) if advisor_status_fk_violation?(error)
    raise Error.new("The current advisor must match the open assignment.", code: :conflict) if advisor_agreement_violation?(error)
    raise Error.new("That advisor assignment overlaps an existing interval.", code: :conflict) if advisor_exclusion_violation?(error)
    raise Error.new("That assignment conflicts with an existing primary.", code: :conflict) if exclusion_violation?(error)

    raise
  rescue ActiveRecord::RecordInvalid => error
    raise Error.new(error.record.errors.full_messages.to_sentence, code: :invalid)
  end

  def lock_offices!(agency, offices)
    Array(offices).compact.uniq.sort_by { |office| office.id.to_s }.each do |office|
      office.lock!
      office.reload
      unless office.agency_id == agency.id
        raise Error.new("That office is not part of this agency.", code: :not_found)
      end
    end
  end

  def lock_memberships!(agency, memberships)
    Array(memberships).compact.uniq.sort_by { |membership| membership.id.to_s }.each do |membership|
      membership.lock!
      membership.reload
      unless membership.agency_id == agency.id
        raise Error.new("That team member is not part of this agency.", code: :not_found)
      end
    end
  end

  def actor_membership!(agency)
    if @privileged
      membership = agency.agency_memberships.order(:id).first
      unless membership&.agency_id == agency.id
        raise Error.new(UNAUTHORIZED, code: :unauthorized)
      end
      return membership
    end

    membership = @actor&.usable_agency_membership
    unless membership && membership.agency_id == agency.id
      raise Error.new(UNAUTHORIZED, code: :unauthorized)
    end

    membership
  end

  def ensure_contact_point_on_party!(party, contact_point)
    return if contact_point.party_id == party.id && contact_point.agency_id == party.agency_id

    raise Error.new("That contact point is not part of this party.", code: :not_found)
  end

  def exclusion_violation?(error)
    error.cause.is_a?(PG::ExclusionViolation)
  end

  def office_status_fk_violation?(error)
    projection_fk_violation?(error, "office_active_projection_fk")
  end

  def party_status_fk_violation?(error)
    projection_fk_violation?(error, "party_active_projection_fk")
  end

  def advisor_status_fk_violation?(error)
    projection_fk_violation?(error, "advisor_active_projection_fk")
  end

  def advisor_exclusion_violation?(error)
    exclusion_violation?(error) && projection_fk_violation?(error, "caa_no_overlapping_intervals")
  end

  def advisor_agreement_violation?(error)
    message = [ error.message, error.cause&.message ].compact.join(" ")
    message.include?("current advisor must agree with open assignment history")
  end

  def projection_fk_violation?(error, constraint_name)
    cause = error.is_a?(ActiveRecord::InvalidForeignKey) ? error : error.cause
    message = [ error.message, cause&.message ].compact.join(" ")
    message.include?(constraint_name)
  end
end
