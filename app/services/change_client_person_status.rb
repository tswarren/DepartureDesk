class ChangeClientPersonStatus < AgencyCommand
  def initialize(agency:, actor:, client_person:, status:, lock_version:)
    @agency = agency
    @actor = actor
    @client_person = client_person
    @status = status
    @lock_version = lock_version
  end

  def call
    ensure_directory_actor!(@actor, @agency, :manage_client_directory)
    ensure_active_agency!(@agency)
    raise Error.new("Choose active or inactive.", code: :invalid) unless ClientPerson::STATUSES.include?(@status)

    ActiveRecord::Base.transaction do
      @agency.lock!
      person = @agency.client_people.lock.find(@client_person.id)
      return Result.new(status: :noop, record: person) if person.status == @status

      if @status == "inactive" && person.client&.active?
        raise Error.new("Inactivate the Client before inactivating this person.", code: :dependency_exists)
      end

      person.lock_version = @lock_version
      person.update!(status: @status)
      cascade_contact_points!(person) if @status == "inactive"
      audit!(
        agency: @agency,
        action: @status == "inactive" ? "client_person.inactivated" : "client_person.reactivated",
        subject: person,
        actor: @actor,
        details: { "client_person_id" => person.id, "status" => @status }
      )
      Result.new(status: :updated, record: person)
    end
  rescue ActiveRecord::StaleObjectError
    raise Error.new("This record changed. Reload it and try again.", code: :conflict)
  end

  private

  def cascade_contact_points!(person)
    [ person.email_addresses, person.phone_numbers, person.postal_addresses ].each do |points|
      points.lock.order(:id).each do |point|
        next if point.inactive? && !point.preferred?

        point.update!(status: "inactive", preferred: false)
      end
    end
  end
end
