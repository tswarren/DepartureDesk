class CreateClientOrganizationEmailAddress < ClientOrganizationContactPointCommand
  COMMAND = "CreateClientOrganizationEmailAddress"

  def call
    prepare!
    ActiveRecord::Base.transaction do
      @agency.lock!
      organization = locked_organization
      raise Error.new("That organization is not active.", code: :invalid_state) unless organization.active?

      address = @attributes[:address].to_s.strip
      fingerprint = DuplicateAcknowledgement.fingerprint("address" => address.downcase)
      point_id = SecureRandom.uuid_v7
      decision = DirectoryDuplicateGate.new(
        agency: @agency, actor: @actor, command: COMMAND, token: @acknowledgement_token,
        reason: @acknowledgement_reason, fingerprint: fingerprint,
        proposed_ids: { "organization_id" => organization.id, "contact_point_id" => point_id, "contact_class" => "ClientOrganizationEmailAddress" }
      ).call { FindClientOrganizationDuplicates.call(agency: @agency, actor: @actor, names: {}, emails: [ address ], exclude_organization_id: organization.id) }
      return decision if decision.is_a?(Result)

      point = organization.email_addresses.create!(
        id: decision&.dig("contact_point_id") || point_id,
        agency: @agency,
        address: address,
        label: @attributes[:label],
        preferred: false,
        status: "active"
      )
      prefer!(organization.email_addresses, point) if ActiveModel::Type::Boolean.new.cast(@attributes[:preferred])
      audit_contact!(organization, changed_fields: [ "email_address" ])
      audit_override!(organization, decision) if decision
      Result.new(status: :created, record: point)
    end
  rescue ActiveRecord::RecordInvalid => error
    raise Error.new(error.record.errors.full_messages.to_sentence, code: :invalid)
  end
end
