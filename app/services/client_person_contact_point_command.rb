class ClientPersonContactPointCommand < AgencyCommand
  def initialize(agency:, actor:, client_person:, record: nil, attributes: {}, lock_version: nil, acknowledgement_token: nil, acknowledgement_reason: nil, status: nil)
    @agency = agency
    @actor = actor
    @client_person = client_person
    @record = record
    @attributes = attributes.to_h.symbolize_keys
    @lock_version = lock_version
    @acknowledgement_token = acknowledgement_token
    @acknowledgement_reason = acknowledgement_reason
    @status = status
  end

  private

  def prepare!
    ensure_directory_actor!(@actor, @agency, :manage_client_directory)
    ensure_active_agency!(@agency)
    raise Error.new("That person could not be found.", code: :invalid) unless @client_person&.agency_id == @agency.id
  end

  def locked_person
    @locked_person ||= @agency.client_people.lock.find(@client_person.id)
  end

  def audit_contact!(person, changed_fields:)
    audit!(
      agency: @agency,
      action: "client_person.contact_updated",
      subject: person,
      actor: @actor,
      details: { "client_person_id" => person.id, "changed_fields" => changed_fields }
    )
  end

  def apply_preferred!(scope, point, preferred, lock_version: nil)
    preferred = ActiveModel::Type::Boolean.new.cast(preferred)
    current = locked_channel_row(scope, point)
    if lock_version && current.lock_version != lock_version.to_i
      raise ActiveRecord::StaleObjectError.new(current, "lock_version")
    end
    return false if current.preferred? == preferred
    raise Error.new("Only an active record can be preferred.", code: :invalid_state) if preferred && !current.active?

    if preferred
      locked_channel_rows(scope).each do |row|
        next unless row.preferred? && row.id != current.id

        row.update!(preferred: false)
      end
    end
    current.update!(preferred: preferred)
    true
  end

  def require_lock_version!
    raise Error.new("This record changed. Reload it and try again.", code: :conflict) if @lock_version.nil?
  end

  def locked_channel_row(scope, record)
    locked_channel_rows(scope).find { |row| row.id == record.id } || raise(ActiveRecord::RecordNotFound)
  end

  def locked_channel_rows(scope)
    scope.order(:id).lock.to_a
  end

  def audit_override!(person, decision = nil)
    audit!(
      agency: @agency,
      action: "client_person.duplicate_override",
      subject: person,
      actor: @actor,
      details: duplicate_override_details(decision, reason: @acknowledgement_reason)
    )
  end
end
