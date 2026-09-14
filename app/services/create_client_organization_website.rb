class CreateClientOrganizationWebsite < ClientOrganizationContactPointCommand
  COMMAND = "CreateClientOrganizationWebsite"

  def call
    prepare!
    ActiveRecord::Base.transaction do
      @agency.lock!
      organization = locked_organization
      raise Error.new("That organization is not active.", code: :invalid_state) unless organization.active?

      website = normalize_website!
      fingerprint = DuplicateAcknowledgement.fingerprint("normalized_host" => website.normalized_host)
      point_id = SecureRandom.uuid_v7
      decision = DirectoryDuplicateGate.new(
        agency: @agency, actor: @actor, command: COMMAND, token: @acknowledgement_token,
        reason: @acknowledgement_reason, fingerprint: fingerprint,
        proposed_ids: { "organization_id" => organization.id, "contact_point_id" => point_id, "contact_class" => "ClientOrganizationWebsite" }
      ).call { FindClientOrganizationDuplicates.call(agency: @agency, actor: @actor, names: {}, websites: [ website ], exclude_organization_id: organization.id) }
      return decision if decision.is_a?(Result)

      point = organization.websites.create!(
        id: decision&.dig("contact_point_id") || point_id,
        agency: @agency,
        url: website.url,
        normalized_url: website.normalized_url,
        normalized_host: website.normalized_host,
        label: @attributes[:label],
        preferred: false,
        status: "active"
      )
      prefer!(organization.websites, point) if ActiveModel::Type::Boolean.new.cast(@attributes[:preferred])
      audit_contact!(organization, changed_fields: [ "website" ])
      audit_override!(organization, decision) if decision
      Result.new(status: :created, record: point)
    end
  rescue ActiveRecord::RecordInvalid => error
    raise Error.new(error.record.errors.full_messages.to_sentence, code: :invalid)
  end

  private

  def normalize_website!
    WebsiteNormalizer.call(url: @attributes[:url]).tap do |website|
      raise Error.new(website.error, code: :invalid) if website.error
    end
  end
end
