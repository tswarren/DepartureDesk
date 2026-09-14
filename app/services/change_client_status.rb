class ChangeClientStatus < AgencyCommand
  def initialize(agency:, actor:, client:, status:, lock_version:)
    @agency = agency
    @actor = actor
    @client = client
    @status = status
    @lock_version = lock_version
  end

  def call
    ensure_directory_actor!(@actor, @agency, :manage_client_directory)
    ensure_active_agency!(@agency)
    raise Error.new("Choose active or inactive.", code: :invalid) unless Client::STATUSES.include?(@status)

    ActiveRecord::Base.transaction do
      @agency.lock!
      source = lock_source!
      client = @agency.clients.lock.find(@client.id)
      raise Error.new("Reactivate the source before reactivating this Client.", code: :dependency_exists) if @status == "active" && source.inactive?
      return Result.new(status: :noop, record: client) if client.status == @status

      client.lock_version = @lock_version
      client.update!(status: @status)
      audit!(
        agency: @agency,
        action: @status == "inactive" ? "client.inactivated" : "client.reactivated",
        subject: client,
        actor: @actor,
        details: audit_details(client, source)
      )
      Result.new(status: :updated, record: client)
    end
  rescue ActiveRecord::StaleObjectError
    raise Error.new("This record changed. Reload it and try again.", code: :conflict)
  end

  private

  def lock_source!
    if @client.client_person_id.present?
      @agency.client_people.lock.find(@client.client_person_id)
    elsif @client.client_organization_id.present?
      @agency.client_organizations.lock.find(@client.client_organization_id)
    else
      raise Error.new("Client source is missing.", code: :invalid)
    end
  end

  def audit_details(client, source)
    details = { "client_id" => client.id, "status" => @status }
    if source.is_a?(ClientPerson)
      details.merge("client_person_id" => source.id)
    else
      details.merge("client_organization_id" => source.id)
    end
  end
end
