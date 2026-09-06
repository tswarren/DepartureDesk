class DirectoryCommand < MembershipCommand
  private

  def with_directory_locks(agency, parties: [], records: [])
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
        ensure_agency_operator!(agency)
        yield
      end
    end
  rescue ActiveRecord::RecordNotUnique
    raise Error.new("That directory record already exists.", code: :conflict)
  rescue ActiveRecord::RecordInvalid => error
    raise Error.new(error.record.errors.full_messages.to_sentence, code: :invalid)
  rescue ActiveRecord::StatementInvalid => error
    raise Error.new("That assignment conflicts with an existing primary.", code: :conflict) if exclusion_violation?(error)

    raise
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
end
