class CreateClientPersonAndOrganizationContact < ClientOrganizationContactCommand
  COMMAND = "CreateClientPersonAndOrganizationContact"

  def initialize(agency:, actor:, client_organization:, names:, attributes:, acknowledgement_token: nil, acknowledgement_reason: nil)
    @agency = agency
    @actor = actor
    @client_organization = client_organization
    @names = names.to_h.symbolize_keys
    @attributes = attributes.to_h.symbolize_keys
    @acknowledgement_token = acknowledgement_token
    @acknowledgement_reason = acknowledgement_reason
  end

  def call
    ensure_assignment_actor!
    raise Error.new("That organization could not be found.", code: :invalid) unless @client_organization&.agency_id == @agency.id

    starts_on = normalize_date(@attributes[:starts_on])
    ends_on = normalize_date(@attributes[:ends_on])
    raise Error.new("Choose a start date.", code: :invalid) unless starts_on
    reject_future_date!(starts_on, field: :starts_on)
    reject_future_date!(ends_on, field: :ends_on)
    raise Error.new("End date cannot be before start date.", code: :invalid) if ends_on && ends_on < starts_on

    primary = ActiveModel::Type::Boolean.new.cast(@attributes[:primary]) || false
    raise Error.new("Historical contacts cannot be primary.", code: :invalid_state) if primary && ends_on.present?

    ActiveRecord::Base.transaction do
      @agency.lock!
      organization = @agency.client_organizations.lock.find(@client_organization.id)
      raise Error.new("That organization is not active.", code: :invalid_state) unless organization.active?

      person_id = SecureRandom.uuid_v7
      decision = acknowledge!(person_id)
      return decision if decision.is_a?(Result)

      lock_current_assignments!(organization)
      clear_current_primary!(organization) if primary
      person = @agency.client_people.create!(id: decision&.dig("person_id") || person_id, **normalized_names, status: "active")
      assignment = organization.organization_contacts.create!(
        agency: @agency,
        client_person: person,
        starts_on: starts_on,
        ends_on: ends_on,
        title: @attributes[:title],
        role_label: @attributes[:role_label],
        primary: primary
      )
      audit!(agency: @agency, action: "client_person.created", subject: person, actor: @actor, details: { "client_person_id" => person.id })
      audit_override!(person, decision) if decision
      audit_contact_added!(organization, assignment)
      Result.new(status: :created, record: assignment)
    end
  rescue ActiveRecord::RecordInvalid => error
    raise Error.new(error.record.errors.full_messages.to_sentence, code: :invalid)
  rescue ActiveRecord::RecordNotUnique, ActiveRecord::StatementInvalid => error
    assignment_conflict!(error)
  end

  private

  def acknowledge!(person_id)
    DirectoryDuplicateGate.new(
      agency: @agency,
      actor: @actor,
      command: COMMAND,
      token: @acknowledgement_token,
      reason: @acknowledgement_reason,
      fingerprint: name_fingerprint,
      proposed_ids: { "person_id" => person_id }
    ).call { FindClientPersonDuplicates.call(agency: @agency, actor: @actor, names: normalized_names) }
  end

  def normalized_names
    @normalized_names ||= @names.slice(:first_name, :middle_name, :last_name, :suffix, :preferred_name)
  end

  def name_fingerprint
    DuplicateAcknowledgement.fingerprint(normalized_names.transform_values { |value| SearchNormalizer.normalize(value) })
  end

  def audit_override!(person, decision)
    audit!(
      agency: @agency,
      action: "client_person.duplicate_override",
      subject: person,
      actor: @actor,
      details: duplicate_override_details(decision, reason: @acknowledgement_reason)
    )
  end

  def clear_current_primary!(organization)
    organization.organization_contacts.current.where(primary: true).order(:id).lock.each do |assignment|
      assignment.update!(primary: false)
    end
  end
end
