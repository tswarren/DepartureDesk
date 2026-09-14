class CreateClientOrganizationPostalAddress < ClientOrganizationContactPointCommand
  COMMAND = "CreateClientOrganizationPostalAddress"

  def call
    prepare!
    ActiveRecord::Base.transaction do
      @agency.lock!
      organization = locked_organization
      raise Error.new("That organization is not active.", code: :invalid_state) unless organization.active?
      raise Error.new("Enter an accepted country.", code: :invalid) unless CountryCode.accepted?(@attributes[:country_code])

      fingerprint = postal_fingerprint
      point_id = SecureRandom.uuid_v7
      decision = DirectoryDuplicateGate.new(
        agency: @agency, actor: @actor, command: COMMAND, token: @acknowledgement_token,
        reason: @acknowledgement_reason, fingerprint: fingerprint,
        proposed_ids: { "organization_id" => organization.id, "contact_point_id" => point_id, "contact_class" => "ClientOrganizationPostalAddress" }
      ).call do
        FindClientOrganizationDuplicates.call(
          agency: @agency, actor: @actor, names: {}, postal_codes: [ @attributes[:postal_code] ], exclude_organization_id: organization.id
        )
      end
      return decision if decision.is_a?(Result)

      point = organization.postal_addresses.create!(
        id: decision&.dig("contact_point_id") || point_id,
        agency: @agency,
        line_1: @attributes[:line_1],
        line_2: @attributes[:line_2],
        locality: @attributes[:locality],
        region: @attributes[:region],
        postal_code: @attributes[:postal_code],
        country_code: @attributes[:country_code],
        label: @attributes[:label],
        preferred: false,
        status: "active"
      )
      prefer!(organization.postal_addresses, point) if ActiveModel::Type::Boolean.new.cast(@attributes[:preferred])
      audit_contact!(organization, changed_fields: [ "postal_address" ])
      audit_override!(organization, decision) if decision
      Result.new(status: :created, record: point)
    end
  rescue ActiveRecord::RecordInvalid => error
    raise Error.new(error.record.errors.full_messages.to_sentence, code: :invalid)
  end

  private

  def postal_fingerprint
    DuplicateAcknowledgement.fingerprint(
      "line_1" => SearchNormalizer.normalize(@attributes[:line_1]),
      "postal_code" => SearchNormalizer.normalize(@attributes[:postal_code]),
      "country_code" => @attributes[:country_code].to_s.upcase
    )
  end
end
