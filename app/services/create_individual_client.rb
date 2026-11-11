class CreateIndividualClient < AgencyCommand
  include ClientReferenceIssuance
  COMMAND = "CreateIndividualClient"

  # also_traveling (CLT-11) creates a traveler with the same name, linked as Self.
  def initialize(agency:, actor:, names:, acknowledgement_token: nil, acknowledgement_reason: nil, also_traveling: false)
    @also_traveling = ActiveModel::Type::Boolean.new.cast(also_traveling)
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
      person_id = SecureRandom.uuid_v7
      client_id = SecureRandom.uuid_v7
      decision = acknowledge!(person_id, client_id)
      return decision if decision.is_a?(Result)

      person = @agency.client_people.create!(id: decision&.dig("person_id") || person_id, **normalized_names, status: "active")
      client = @agency.clients.create!(
        id: decision&.dig("client_id") || client_id,
        client_person: person,
        client_reference: issue_client_reference!(@agency),
        status: "active",
        created_by: @actor
      )
      audit!(agency: @agency, action: "client_person.created", subject: person, actor: @actor, details: { "client_person_id" => person.id })
      audit!(agency: @agency, action: "client.created", subject: client, actor: @actor, details: { "client_id" => client.id, "client_person_id" => person.id })
      audit_override!(person, client, decision) if decision
      create_self_traveler!(person, client) if @also_traveling
      Result.new(status: :created, record: client)
    end
  rescue ActiveRecord::RecordInvalid => error
    raise Error.new(error.record.errors.full_messages.to_sentence, code: :invalid)
  end

  private

  def acknowledge!(person_id, client_id)
    DirectoryDuplicateGate.new(
      agency: @agency,
      actor: @actor,
      command: COMMAND,
      token: @acknowledgement_token,
      reason: @acknowledgement_reason,
      fingerprint: name_fingerprint,
      proposed_ids: { "person_id" => person_id, "client_id" => client_id }
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

  def create_self_traveler!(person, client)
    traveler = @agency.travelers.create!(given_names: person.first_name, middle_name: person.middle_name, surname: person.last_name,
      suffix: person.suffix, preferred_name: person.preferred_name, created_by: @actor)
    audit!(agency: @agency, action: "traveler.created", subject: traveler, actor: @actor, details: { "traveler_id" => traveler.id, "self_of_client_id" => client.id })
    @agency.traveler_links.create!(client:, traveler:, relationship: "self")
    audit!(agency: @agency, action: "client.traveler_linked", subject: client, actor: @actor, details: { "traveler_id" => traveler.id, "relationship" => "self" })
  end

  def audit_override!(person, client, decision)
    audit!(
      agency: @agency,
      action: "client_person.duplicate_override",
      subject: person,
      actor: @actor,
      details: duplicate_override_details(decision, reason: @acknowledgement_reason, extra: { "client_id" => client.id })
    )
  end
end
