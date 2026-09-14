class UpdateClientOrganization < AgencyCommand
  COMMAND = "UpdateClientOrganization"

  def initialize(agency:, actor:, client_organization:, names:, lock_version:, acknowledgement_token: nil, acknowledgement_reason: nil)
    @agency = agency
    @actor = actor
    @client_organization = client_organization
    @names = names.to_h.symbolize_keys
    @lock_version = lock_version
    @acknowledgement_token = acknowledgement_token
    @acknowledgement_reason = acknowledgement_reason
  end

  def call
    ensure_directory_actor!(@actor, @agency, :manage_client_directory)
    ensure_active_agency!(@agency)

    ActiveRecord::Base.transaction do
      @agency.lock!
      organization = @agency.client_organizations.lock.find(@client_organization.id)
      organization.lock_version = @lock_version
      return Result.new(status: :noop, record: organization) if unchanged?(organization)

      decision = acknowledge!(organization)
      return decision if decision.is_a?(Result)

      organization.update!(normalized_names)
      audit!(agency: @agency, action: "client_organization.updated", subject: organization, actor: @actor, details: { "client_organization_id" => organization.id, "changed_fields" => normalized_names.keys.map(&:to_s) })
      audit_override!(organization, decision) if decision
      Result.new(status: :updated, record: organization)
    end
  rescue ActiveRecord::StaleObjectError
    raise Error.new("This record changed. Reload it and try again.", code: :conflict)
  rescue ActiveRecord::RecordInvalid => error
    raise Error.new(error.record.errors.full_messages.to_sentence, code: :invalid)
  end

  private

  def unchanged?(organization)
    normalized_names.all? { |key, value| organization.public_send(key).presence == value.presence }
  end

  def acknowledge!(organization)
    DirectoryDuplicateGate.new(
      agency: @agency,
      actor: @actor,
      command: COMMAND,
      token: @acknowledgement_token,
      reason: @acknowledgement_reason,
      fingerprint: name_fingerprint,
      target: organization,
      current_fingerprint: -> { stored_fingerprint(organization) }
    ).call { candidates(organization) }
  end

  def candidates(organization)
    FindClientOrganizationDuplicates.call(agency: @agency, actor: @actor, names: normalized_names, exclude_organization_id: organization.id)
  end

  def normalized_names
    @normalized_names ||= @names.slice(:display_name, :legal_name)
  end

  def name_fingerprint
    DuplicateAcknowledgement.fingerprint(normalized_names.transform_values { |value| SearchNormalizer.normalize(value) })
  end

  def stored_fingerprint(organization)
    DuplicateAcknowledgement.fingerprint(
      %i[display_name legal_name].index_with { |key| SearchNormalizer.normalize(organization.public_send(key)) }
    )
  end

  def audit_override!(organization, decision)
    audit!(
      agency: @agency,
      action: "client_organization.duplicate_override",
      subject: organization,
      actor: @actor,
      details: duplicate_override_details(decision, reason: @acknowledgement_reason)
    )
  end
end
