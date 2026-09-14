class CreateClientPerson < AgencyCommand
  COMMAND = "CreateClientPerson"

  def initialize(agency:, actor:, names:, acknowledgement_token: nil, acknowledgement_reason: nil)
    @agency = agency
    @actor = actor
    @names = names.to_h.symbolize_keys
    @acknowledgement_token = acknowledgement_token
    @acknowledgement_reason = acknowledgement_reason
  end

  def call
    ensure_permitted!(@actor, :manage_client_directory)
    ensure_active_agency!(@agency)

    ActiveRecord::Base.transaction do
      @agency.lock!
      person_id = SecureRandom.uuid_v7
      decision = acknowledge!(person_id)
      return decision if decision.is_a?(Result)

      person = @agency.client_people.create!(id: decision&.dig("person_id") || person_id, **normalized_names, status: "active")
      audit!(agency: @agency, action: "client_person.created", subject: person, actor: @actor, details: { "client_person_id" => person.id })
      audit_override!(person) if decision
      Result.new(status: :created, record: person)
    end
  rescue ActiveRecord::RecordInvalid => error
    raise Error.new(error.record.errors.full_messages.to_sentence, code: :invalid)
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
    ).call { candidates }
  end

  def candidates
    FindClientPersonDuplicates.call(agency: @agency, actor: @actor, names: normalized_names)
  end

  def normalized_names
    @normalized_names ||= @names.slice(:first_name, :middle_name, :last_name, :suffix, :preferred_name)
  end

  def name_fingerprint
    DuplicateAcknowledgement.fingerprint(normalized_names.transform_values { |value| SearchNormalizer.normalize(value) })
  end

  def audit_override!(person)
    audit!(
      agency: @agency,
      action: "client_person.duplicate_override",
      subject: person,
      actor: @actor,
      details: { "reason_code" => @acknowledgement_reason }
    )
  end
end
