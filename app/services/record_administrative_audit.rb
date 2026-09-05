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
end
