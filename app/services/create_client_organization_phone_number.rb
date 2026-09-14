class CreateClientOrganizationPhoneNumber < ClientOrganizationContactPointCommand
  COMMAND = "CreateClientOrganizationPhoneNumber"

  def call
    prepare!
    ActiveRecord::Base.transaction do
      @agency.lock!
      organization = locked_organization
      raise Error.new("That organization is not active.", code: :invalid_state) unless organization.active?

      phone = PhoneNumberNormalizer.call(number: @attributes[:number], extension: @attributes[:extension], country_code: @attributes[:country_code])
      fingerprint = DuplicateAcknowledgement.fingerprint("number" => phone.normalized_number, "extension" => phone.extension.to_s)
      point_id = SecureRandom.uuid_v7
      decision = DirectoryDuplicateGate.new(
        agency: @agency, actor: @actor, command: COMMAND, token: @acknowledgement_token,
        reason: @acknowledgement_reason, fingerprint: fingerprint,
        proposed_ids: { "organization_id" => organization.id, "contact_point_id" => point_id, "contact_class" => "ClientOrganizationPhoneNumber" }
      ).call { FindClientOrganizationDuplicates.call(agency: @agency, actor: @actor, names: {}, phones: [ phone ], exclude_organization_id: organization.id) }
      return decision if decision.is_a?(Result)

      point = organization.phone_numbers.create!(
        id: decision&.dig("contact_point_id") || point_id,
        agency: @agency,
        number: phone.number,
        normalized_number: phone.normalized_number,
        extension: phone.extension,
        country_code: phone.country_code,
        label: @attributes[:label],
        preferred: false,
        status: "active"
      )
      prefer!(organization.phone_numbers, point) if ActiveModel::Type::Boolean.new.cast(@attributes[:preferred])
      audit_contact!(organization, changed_fields: [ "phone_number" ])
      audit_override!(organization, decision) if decision
      Result.new(status: :created, record: point)
    end
  rescue ActiveRecord::RecordInvalid => error
    raise Error.new(error.record.errors.full_messages.to_sentence, code: :invalid)
  end
end
