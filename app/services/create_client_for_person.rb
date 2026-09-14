class CreateClientForPerson < AgencyCommand
  include ClientReferenceIssuance

  def initialize(agency:, actor:, client_person:)
    @agency = agency
    @actor = actor
    @client_person = client_person
  end

  def call
    ensure_permitted!(@actor, :manage_client_directory)
    ensure_active_agency!(@agency)
    raise Error.new("That person could not be found.", code: :invalid) unless @client_person&.agency_id == @agency.id

    ActiveRecord::Base.transaction do
      @agency.lock!
      person = @agency.client_people.lock.find(@client_person.id)
      raise Error.new("That person is not active.", code: :invalid_state) unless person.active?
      if (existing = person.client)
        raise Error.new("That person already has a Client. Reactivate it instead of creating another.", code: :already_exists)
      end

      client = @agency.clients.create!(
        client_person: person,
        client_reference: issue_client_reference!(@agency),
        status: "active"
      )
      audit!(agency: @agency, action: "client.created", subject: client, actor: @actor, details: { "client_id" => client.id, "client_person_id" => person.id })
      Result.new(status: :created, record: client)
    end
  rescue ActiveRecord::RecordInvalid => error
    raise Error.new(error.record.errors.full_messages.to_sentence, code: :invalid)
  end
end
