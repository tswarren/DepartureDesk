class DirectoryCommand < MembershipCommand
  private

  def with_directory_locks(agency, parties: [], records: [], offices: [])
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
    cause = error.is_a?(ActiveRecord::InvalidForeignKey) ? error : error.cause
    message = [ error.message, cause&.message ].compact.join(" ")
    message.include?("office_active_projection_fk")
  end
end
