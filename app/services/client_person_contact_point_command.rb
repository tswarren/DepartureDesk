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
    ensure_permitted!(@actor, :manage_client_directory)
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

  def apply_preferred!(scope, point, preferred)
    preferred = ActiveModel::Type::Boolean.new.cast(preferred)
    return if point.preferred? == preferred
    raise Error.new("Only an active record can be preferred.", code: :invalid_state) if preferred && !point.active?

    scope.where.not(id: point.id).update_all(preferred: false, updated_at: Time.current) if preferred
    point.update!(preferred: preferred)
  end

  def audit_override!(person)
    audit!(
      agency: @agency,
      action: "client_person.duplicate_override",
      subject: person,
      actor: @actor,
      details: { "reason_code" => @acknowledgement_reason }
    )
  end
end
