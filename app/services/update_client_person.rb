class UpdateClientPerson < AgencyCommand
  COMMAND = "UpdateClientPerson"

  def initialize(agency:, actor:, client_person:, names:, lock_version:, acknowledgement_token: nil, acknowledgement_reason: nil)
    @agency = agency
    @actor = actor
    @client_person = client_person
    @names = names.to_h.symbolize_keys
    @lock_version = lock_version
    @acknowledgement_token = acknowledgement_token
    @acknowledgement_reason = acknowledgement_reason
  end

  def call
    ensure_permitted!(@actor, :manage_client_directory)
    ensure_active_agency!(@agency)

    ActiveRecord::Base.transaction do
      @agency.lock!
      person = @agency.client_people.lock.find(@client_person.id)
      person.lock_version = @lock_version
      return Result.new(status: :noop, record: person) if unchanged?(person)

      decision = acknowledge!(person)
      return decision if decision.is_a?(Result)

      person.update!(normalized_names)
      audit!(agency: @agency, action: "client_person.updated", subject: person, actor: @actor, details: { "client_person_id" => person.id, "changed_fields" => normalized_names.keys.map(&:to_s) })
      audit_override!(person) if decision
      Result.new(status: :updated, record: person)
    end
  rescue ActiveRecord::StaleObjectError
    raise Error.new("This record changed. Reload it and try again.", code: :conflict)
  rescue ActiveRecord::RecordInvalid => error
    raise Error.new(error.record.errors.full_messages.to_sentence, code: :invalid)
  end

  private

  def unchanged?(person)
    normalized_names.all? { |key, value| person.public_send(key).presence == value.presence }
  end

  def acknowledge!(person)
    DirectoryDuplicateGate.new(
      agency: @agency,
      actor: @actor,
      command: COMMAND,
      token: @acknowledgement_token,
      reason: @acknowledgement_reason,
      fingerprint: name_fingerprint,
      target: person,
      current_fingerprint: -> { stored_fingerprint(person) }
    ).call { candidates(person) }
  end

  def candidates(person)
    FindClientPersonDuplicates.call(agency: @agency, actor: @actor, names: normalized_names, exclude_person_id: person.id)
  end

  def normalized_names
    @normalized_names ||= @names.slice(:first_name, :middle_name, :last_name, :suffix, :preferred_name)
  end

  def name_fingerprint
    DuplicateAcknowledgement.fingerprint(normalized_names.transform_values { |value| SearchNormalizer.normalize(value) })
  end

  def stored_fingerprint(person)
    DuplicateAcknowledgement.fingerprint(
      %i[first_name middle_name last_name suffix preferred_name].index_with { |key| SearchNormalizer.normalize(person.public_send(key)) }
    )
  end

  def audit_override!(person)
    audit!(agency: @agency, action: "client_person.duplicate_override", subject: person, actor: @actor, details: { "reason_code" => @acknowledgement_reason })
  end
end
