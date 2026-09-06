class UpdatePartyContactPoint < DirectoryCommand
  def initialize(agency:, party:, contact_point:, attributes:, actor: nil, actor_identifier: nil, privileged: false, label: nil, lock_version: nil)
    @agency = agency
    @party = party
    @contact_point = contact_point
    @attributes = attributes.to_h.with_indifferent_access
    @label = label
    @lock_version = lock_version
    assign_command_actors(actor:, actor_identifier:, privileged:)
  end

  def call
    with_directory_locks(@agency, parties: [ @party ], records: [ @contact_point ]) { perform }
  rescue PhoneNumberNormalizer::Error, EmailAddressNormalizer::Error => error
    raise Error.new(error.message, code: :invalid)
  rescue ActiveRecord::StaleObjectError
    raise Error.new("This contact information was changed by someone else. Refresh and try again.", code: :conflict)
  end

  private

  def perform
    ensure_contact_point_on_party!(@party, @contact_point)
    unless @contact_point.active?
      raise Error.new("Deactivated contact information cannot be edited in place.", code: :invalid)
    end

    detail = ContactPointDetails.build(
      contact_kind: @contact_point.contact_kind,
      attributes: @attributes,
      agency: @agency
    )

    if @lock_version.present? && @contact_point.lock_version != @lock_version.to_i
      raise ActiveRecord::StaleObjectError.new(@contact_point, "update")
    end

    @contact_point.assign_attributes(
      label: @label,
      normalized_value: detail[:normalized_value]
    )
    @contact_point.save!
    ContactPointDetails.write!(@contact_point, detail)

    audit!(
      agency: @agency,
      action: "directory.contact_updated",
      subject: @contact_point,
      details: {
        "party_id" => @party.id,
        "contact_point_id" => @contact_point.id,
        "contact_kind" => @contact_point.contact_kind
      },
      **actor_audit_args
    )
    CommandResult.new(status: :accepted, party: @party, contact_point: @contact_point)
  end
end
