class CreateClientOrganization < AgencyCommand
  COMMAND = "CreateClientOrganization"

  def initialize(agency:, actor:, names:, acknowledgement_token: nil, acknowledgement_reason: nil)
    @agency = agency
    @actor = actor
    @names = names.to_h.symbolize_keys
    @acknowledgement_token = acknowledgement_token
    @acknowledgement_reason = acknowledgement_reason
  end

  def call
    ensure_directory_actor!(@actor, @agency, :manage_client_directory)
    ensure_active_agency!(@agency)

    ActiveRecord::Base.transaction do
      @agency.lock!
      organization_id = SecureRandom.uuid_v7
      decision = acknowledge!(organization_id)
      return decision if decision.is_a?(Result)

      organization = @agency.client_organizations.create!(id: decision&.dig("organization_id") || organization_id, **normalized_names, status: "active")
      audit!(agency: @agency, action: "client_organization.created", subject: organization, actor: @actor, details: { "client_organization_id" => organization.id })
      audit_override!(organization, decision) if decision
      Result.new(status: :created, record: organization)
    end
  rescue ActiveRecord::RecordInvalid => error
    raise Error.new(error.record.errors.full_messages.to_sentence, code: :invalid)
  end

  private

  def acknowledge!(organization_id)
    DirectoryDuplicateGate.new(
      agency: @agency,
      actor: @actor,
      command: COMMAND,
      token: @acknowledgement_token,
      reason: @acknowledgement_reason,
      fingerprint: name_fingerprint,
      proposed_ids: { "organization_id" => organization_id }
    ).call { candidates }
  end

  def candidates
    FindClientOrganizationDuplicates.call(agency: @agency, actor: @actor, names: normalized_names)
  end

  def normalized_names
    @normalized_names ||= @names.slice(:display_name, :legal_name)
  end

  def name_fingerprint
    DuplicateAcknowledgement.fingerprint(normalized_names.transform_values { |value| SearchNormalizer.normalize(value) })
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
