class UpdateClientOrganizationWebsite < ClientOrganizationContactPointCommand
  COMMAND = "UpdateClientOrganizationWebsite"

  def call
    prepare!
    ActiveRecord::Base.transaction do
      @agency.lock!
      organization = locked_organization
      point = locked_channel_row(organization.websites, @record)
      point.lock_version = @lock_version
      website = normalize_website!
      preferred = ActiveModel::Type::Boolean.new.cast(@attributes[:preferred])
      identity_unchanged = point.normalized_url == website.normalized_url && point.label == @attributes[:label].presence
      return Result.new(status: :noop, record: point) if identity_unchanged && point.preferred? == preferred

      decision = nil
      unless identity_unchanged
        fingerprint = DuplicateAcknowledgement.fingerprint("normalized_host" => website.normalized_host)
        decision = DirectoryDuplicateGate.new(
          agency: @agency, actor: @actor, command: COMMAND, token: @acknowledgement_token,
          reason: @acknowledgement_reason, fingerprint: fingerprint, target: point,
          current_fingerprint: -> { DuplicateAcknowledgement.fingerprint("normalized_host" => point.normalized_host) }
        ).call { FindClientOrganizationDuplicates.call(agency: @agency, actor: @actor, names: {}, websites: [ website ], exclude_organization_id: organization.id) }
        return decision if decision.is_a?(Result)

        point.update!(url: website.url, normalized_url: website.normalized_url, normalized_host: website.normalized_host, label: @attributes[:label])
      end
      apply_preferred!(organization.websites, point, preferred, lock_version: identity_unchanged ? @lock_version : nil)
      audit_contact!(organization, record: point, changed_fields: [ "website" ])
      audit_override!(organization, decision) if decision
      Result.new(status: :updated, record: point)
    end
  rescue ActiveRecord::StaleObjectError
    raise Error.new("This record changed. Reload it and try again.", code: :conflict)
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
