class RecordAdministrativeAudit
  PROFILE_FIELDS = %w[
    name
    legal_name
    country_code
    default_timezone
    default_currency
  ].freeze

  def self.record(...)
    new.record(...)
  end

  def record(agency:, action:, actor_user: nil, actor_identifier: nil, subject: nil, details: {})
    actor_identifier = actor_identifier.to_s.strip.presence

    if actor_user && actor_identifier
      raise ArgumentError, "Provide exactly one of actor_user or actor_identifier."
    end
    if actor_user.nil? && actor_identifier.nil?
      raise ArgumentError, "An actor is required."
    end

    ensure_subject_belongs_to_agency!(agency, subject)

    attributes = {
      agency: agency,
      action: action,
      details: details.stringify_keys,
      created_at: Time.current
    }

    if actor_user
      attributes[:actor_kind] = "user"
      attributes[:actor_user] = actor_user
    else
      attributes[:actor_kind] = "system"
      attributes[:actor_identifier] = actor_identifier
    end

    if subject
      attributes[:subject_type] = subject.class.name
      attributes[:subject_id] = subject.id
    end

    AuditEvent.create!(attributes)
  end

  def self.profile_updated(agency:, actor:, before:, after:)
    changed_fields = PROFILE_FIELDS.select { |field| before[field] != after[field] }

    record(
      agency: agency,
      action: "agency.profile_updated",
      actor_user: actor,
      subject: agency,
      details: {
        "changed_fields" => changed_fields,
        "before" => before.slice(*changed_fields),
        "after" => after.slice(*changed_fields)
      }
    )
  end

  private

  def ensure_subject_belongs_to_agency!(agency, subject)
    case subject
    when Agency
      return if subject.id == agency.id

      raise ArgumentError, "Agency subject must equal the event agency."
    when AgencyMembership
      return if subject.agency_id == agency.id

      raise ArgumentError, "Membership subject must belong to the event agency."
    when Office
      return if subject.agency_id == agency.id

      raise ArgumentError, "Office subject must belong to the event agency."
    when OfficeAssignment
      return if subject.agency_id == agency.id

      raise ArgumentError, "Assignment subject must belong to the event agency."
    end
  end
end
