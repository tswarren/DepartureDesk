class ChangeClientStatus < AgencyCommand
  def initialize(agency:, actor:, client:, status:, lock_version:)
    @agency = agency
    @actor = actor
    @client = client
    @status = status
    @lock_version = lock_version
  end

  def call
    ensure_permitted!(@actor, :manage_client_directory)
    ensure_active_agency!(@agency)
    raise Error.new("Choose active or inactive.", code: :invalid) unless Client::STATUSES.include?(@status)

    ActiveRecord::Base.transaction do
      @agency.lock!
      person = @agency.client_people.lock.find(@client.client_person_id)
      client = @agency.clients.lock.find(@client.id)
      raise Error.new("Reactivate the person before reactivating this Client.", code: :dependency_exists) if @status == "active" && person.inactive?
      return Result.new(status: :noop, record: client) if client.status == @status

      client.lock_version = @lock_version
      client.update!(status: @status)
      audit!(
        agency: @agency,
        action: @status == "inactive" ? "client.inactivated" : "client.reactivated",
        subject: client,
        actor: @actor,
        details: { "client_id" => client.id, "client_person_id" => person.id, "status" => @status }
      )
      Result.new(status: :updated, record: client)
    end
  rescue ActiveRecord::StaleObjectError
    raise Error.new("This record changed. Reload it and try again.", code: :conflict)
  end
end
