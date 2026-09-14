class CreateClientForOrganization < AgencyCommand
  include ClientReferenceIssuance

  def initialize(agency:, actor:, client_organization:)
    @agency = agency
    @actor = actor
    @client_organization = client_organization
  end

  def call
    ensure_directory_actor!(@actor, @agency, :manage_client_directory)
    ensure_active_agency!(@agency)
    raise Error.new("That organization could not be found.", code: :invalid) unless @client_organization&.agency_id == @agency.id

    ActiveRecord::Base.transaction do
      @agency.lock!
      organization = @agency.client_organizations.lock.find(@client_organization.id)
      raise Error.new("That organization is not active.", code: :invalid_state) unless organization.active?
      raise Error.new("That organization already has a Client. Reactivate it instead of creating another.", code: :already_exists) if organization.client

      client = @agency.clients.create!(
        client_organization: organization,
        client_reference: issue_client_reference!(@agency),
        status: "active"
      )
      audit!(agency: @agency, action: "client.created", subject: client, actor: @actor, details: { "client_id" => client.id, "client_organization_id" => organization.id })
      Result.new(status: :created, record: client)
    end
  rescue ActiveRecord::RecordInvalid => error
    raise Error.new(error.record.errors.full_messages.to_sentence, code: :invalid)
  end
end
