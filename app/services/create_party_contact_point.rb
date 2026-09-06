class CreatePartyContactPoint < DirectoryCommand
  def initialize(agency:, party:, contact_kind:, attributes:, actor: nil, actor_identifier: nil, privileged: false, label: nil)
    @agency = agency
    @party = party
    @contact_kind = contact_kind.to_s
    @attributes = attributes.to_h.with_indifferent_access
    @label = label
    assign_command_actors(actor:, actor_identifier:, privileged:)
  end

  def call
    with_directory_locks(@agency, parties: [ @party ]) { perform }
  rescue PhoneNumberNormalizer::Error, EmailAddressNormalizer::Error => error
    raise Error.new(error.message, code: :invalid)
  end

  private

  def perform
    unless PartyContactPoint::KINDS.include?(@contact_kind)
      raise Error.new("Choose an email, phone, or postal address.", code: :invalid)
    end

    detail = ContactPointDetails.build(contact_kind: @contact_kind, attributes: @attributes, agency: @agency)
    existing_active = @party.contact_points.active.find_by(
      contact_kind: @contact_kind,
      normalized_value: detail[:normalized_value]
    )
    if existing_active
      message = if existing_active.suppressed?
        "That contact information is already recorded and marked do not use."
      else
        "That contact information is already recorded."
      end
      raise Error.new(message, code: :conflict)
    end

    existing = @party.contact_points.deactivated
      .where(contact_kind: @contact_kind, normalized_value: detail[:normalized_value])
      .order(:id)
      .last

    if existing
      existing.lock!
      existing.reload
      reactivate!(existing, detail)
    else
      create_new!(detail)
    end
  end

  def create_new!(detail)
    contact_point = @party.contact_points.create!(
      agency: @agency,
      contact_kind: @contact_kind,
      label: @label,
      normalized_value: detail[:normalized_value],
      status: "active"
    )
    ContactPointDetails.write!(contact_point, detail)
    audit_contact!(contact_point, "directory.contact_created", reactivated: false)
    CommandResult.new(status: :created, party: @party, contact_point:)
  end

  def reactivate!(contact_point, detail)
    contact_point.assign_attributes(
      label: @label,
      normalized_value: detail[:normalized_value],
      status: "active",
      deactivated_at: nil,
      deactivated_by_membership: nil,
      deactivation_reason: nil
    )
    contact_point.save!
    ContactPointDetails.write!(contact_point, detail)
    audit_contact!(contact_point, "directory.contact_reactivated", reactivated: true)
    CommandResult.new(status: :accepted, party: @party, contact_point:)
  end

  def audit_contact!(contact_point, action, reactivated:)
    audit!(
      agency: @agency,
      action:,
      subject: contact_point,
      details: {
        "party_id" => @party.id,
        "contact_point_id" => contact_point.id,
        "contact_kind" => contact_point.contact_kind,
        "reactivated" => reactivated
      },
      **actor_audit_args
    )
  end
end
