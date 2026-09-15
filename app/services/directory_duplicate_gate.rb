class DirectoryDuplicateGate
  CONTACT_CLASSES = %w[
    ClientPersonEmailAddress
    ClientPersonPhoneNumber
    ClientPersonPostalAddress
    ClientOrganizationEmailAddress
    ClientOrganizationPhoneNumber
    ClientOrganizationPostalAddress
    ClientOrganizationWebsite
    SupplierEmailAddress
    SupplierPhoneNumber
    SupplierPostalAddress
    SupplierWebsite
    SupplierContactEmailAddress
    SupplierContactPhoneNumber
  ].freeze

  def initialize(agency:, actor:, command:, token:, reason:, fingerprint:, proposed_ids: {}, target: nil, current_fingerprint: nil)
    @agency = agency
    @actor = actor
    @command = command
    @token = token.presence
    @reason = reason
    @fingerprint = fingerprint
    @proposed_ids = proposed_ids
    @target = target
    @current_fingerprint = current_fingerprint
  end

  def call(&candidates)
    @candidates = candidates
    return review_or_payload if @token.blank?

    payload = DuplicateAcknowledgement.verify!(@token, agency: @agency, actor: @actor, command: @command)
    replayed = replay(payload)
    return replayed if replayed

    reviewed = enforce!(payload)
    payload.merge("reviewed_candidates" => candidate_evidence(reviewed))
  end

  private

  def review_or_payload
    require_review!(@candidates.call)
    nil
  end

  def replay(payload)
    payload["shape"] == "update" ? replay_update(payload) : replay_create(payload)
  end

  def replay_create(payload)
    return replay_contact_create(payload) if payload["contact_point_id"].present?
    return replay_supplier_location_create(payload) if payload["supplier_location_id"].present?
    return replay_supplier_contact_create(payload) if payload["supplier_contact_id"].present?

    person = find_person(payload["person_id"])
    organization = find_organization(payload["organization_id"])
    client = find_client(payload["client_id"])
    supplier = find_supplier(payload["supplier_id"])
    expected = [ payload["person_id"], payload["organization_id"], payload["client_id"], payload["supplier_id"] ].compact
    found = [ person, organization, client, supplier ].compact
    return if found.empty?
    raise conflict! if found.size != expected.size || !related?(person, organization, client, supplier, nil)

    AgencyCommand::Result.new(status: :replayed, record: supplier || client || organization || person)
  end

  def replay_supplier_location_create(payload)
    location = find_supplier_location(payload["supplier_location_id"])
    return if location.nil?

    supplier = find_supplier(payload["supplier_id"])
    raise conflict! if incomplete_owner?(payload["supplier_id"], supplier) ||
      !related?(nil, nil, nil, supplier, nil, location: location)

    AgencyCommand::Result.new(status: :replayed, record: location)
  end

  def replay_supplier_contact_create(payload)
    supplier_contact = find_supplier_contact(payload["supplier_contact_id"])
    return if supplier_contact.nil?

    supplier = find_supplier(payload["supplier_id"])
    raise conflict! if incomplete_owner?(payload["supplier_id"], supplier) ||
      !related?(nil, nil, nil, supplier, nil, supplier_contact: supplier_contact)

    AgencyCommand::Result.new(status: :replayed, record: supplier_contact)
  end

  def replay_contact_create(payload)
    contact = find_contact(payload)
    return if contact.nil?

    person = find_person(payload["person_id"])
    organization = find_organization(payload["organization_id"])
    supplier = find_supplier(payload["supplier_id"])
    supplier_contact = find_supplier_contact(payload["supplier_contact_id"])

    raise conflict! if incomplete_owner?(payload["person_id"], person) ||
      incomplete_owner?(payload["organization_id"], organization) ||
      incomplete_owner?(payload["supplier_id"], supplier) ||
      incomplete_owner?(payload["supplier_contact_id"], supplier_contact) ||
      !related?(person, organization, nil, supplier, contact, supplier_contact: supplier_contact)

    AgencyCommand::Result.new(status: :replayed, record: contact)
  end

  def incomplete_owner?(proposed_id, record)
    proposed_id.present? && record.nil?
  end

  def replay_update(payload)
    return unless @target&.id == payload["target_id"]
    return unless @current_fingerprint.call == payload["fingerprint"]

    AgencyCommand::Result.new(status: :replayed, record: @target)
  end

  def enforce!(payload)
    if update_stale?(payload)
      raise AgencyCommand::Error.new("This record changed. Review it again.", code: :conflict)
    end

    found = @candidates.call
    fresh_needed = DuplicateAcknowledgement.expired?(payload) ||
      payload["fingerprint"] != @fingerprint ||
      payload["candidate_digest"] != DuplicateAcknowledgement.candidate_digest(found)
    require_review!(found) if fresh_needed
    return found if DuplicateAcknowledgement::REASONS.include?(@reason)

    raise AgencyCommand::Error.new("Choose why this record is distinct.", code: :invalid)
  end

  def update_stale?(payload)
    return false unless payload["shape"] == "update" && @target

    @current_fingerprint.call != payload["fingerprint"] && @target.lock_version != payload["lock_version"]
  end

  def require_review!(found)
    return if found.empty?

    raise AgencyCommand::DuplicateReviewRequired.new(
      token: DuplicateAcknowledgement.issue(token_payload(found)),
      candidates: found
    )
  end

  def token_payload(found)
    {
      "shape" => @target ? "update" : "create",
      "command" => @command,
      "agency_id" => @agency.id,
      "actor_id" => @actor.id,
      "fingerprint" => @fingerprint,
      "candidate_digest" => DuplicateAcknowledgement.candidate_digest(found),
      "target_id" => @target&.id,
      "lock_version" => @target&.lock_version
    }.merge(@proposed_ids).compact
  end

  def find_person(id)
    return if id.blank?

    @agency.client_people.find_by(id: id)
  end

  def find_client(id)
    return if id.blank?

    @agency.clients.find_by(id: id)
  end

  def find_organization(id)
    return if id.blank?

    @agency.client_organizations.find_by(id: id)
  end

  def find_supplier(id)
    return if id.blank?

    @agency.suppliers.find_by(id: id)
  end

  def find_supplier_location(id)
    return if id.blank?

    @agency.supplier_locations.find_by(id: id)
  end

  def find_supplier_contact(id)
    return if id.blank?

    @agency.supplier_contacts.find_by(id: id)
  end

  def find_contact(payload)
    id = payload["contact_point_id"]
    class_name = payload["contact_class"]
    return if id.blank? || !CONTACT_CLASSES.include?(class_name)

    class_name.constantize.find_by(id: id, agency_id: @agency.id)
  end

  def candidate_evidence(found)
    found.map { |candidate| { "id" => candidate.id, "signals" => Array(candidate.signals).sort } }
      .sort_by { |candidate| candidate["id"] }
  end

  def conflict!
    AgencyCommand::Error.new("That acknowledgement does not match an existing result.", code: :conflict)
  end

  def related?(person, organization, client, supplier, contact, supplier_contact: nil, location: nil)
    return false if client && person && client.client_person_id != person.id
    return false if client && organization && client.client_organization_id != organization.id
    return false if contact && person && contact_attribute(contact, :client_person_id) != person.id
    return false if contact && organization && contact_attribute(contact, :client_organization_id) != organization.id
    return false if contact && supplier_contact && contact_attribute(contact, :supplier_contact_id) != supplier_contact.id
    return false if supplier_contact && supplier && supplier_contact.supplier_id != supplier.id
    return false if location && supplier && location.supplier_id != supplier.id
    return false if contact && supplier && contact_owner_supplier_id(contact) != supplier.id

    person.present? || organization.present? || client.present? || supplier.present? ||
      supplier_contact.present? || location.present?
  end

  def contact_attribute(contact, attribute)
    return unless contact.has_attribute?(attribute)

    contact.public_send(attribute)
  end

  def contact_owner_supplier_id(contact)
    return contact.supplier_id if contact.has_attribute?(:supplier_id)
    return contact.supplier_contact&.supplier_id if contact.has_attribute?(:supplier_contact_id)

    nil
  end
end
