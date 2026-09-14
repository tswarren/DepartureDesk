class ChangeClientOrganizationStatus < AgencyCommand
  include AgencyLocalDate

  def initialize(agency:, actor:, client_organization:, status:, lock_version:)
    @agency = agency
    @actor = actor
    @client_organization = client_organization
    @status = status
    @lock_version = lock_version
  end

  def call
    ensure_directory_actor!(@actor, @agency, :manage_client_directory)
    ensure_active_agency!(@agency)
    raise Error.new("Choose active or inactive.", code: :invalid) unless ClientOrganization::STATUSES.include?(@status)

    ActiveRecord::Base.transaction do
      @agency.lock!
      organization = @agency.client_organizations.lock.find(@client_organization.id)
      return Result.new(status: :noop, record: organization) if organization.status == @status
      raise Error.new("Inactivate the Client before inactivating this organization.", code: :dependency_exists) if @status == "inactive" && organization.client&.active?

      organization.lock_version = @lock_version
      affected = @status == "inactive" ? cascade_dependents!(organization) : empty_affected
      organization.update!(status: @status)
      audit!(
        agency: @agency,
        action: @status == "inactive" ? "client_organization.inactivated" : "client_organization.reactivated",
        subject: organization,
        actor: @actor,
        details: affected.merge("client_organization_id" => organization.id, "status" => @status)
      )
      Result.new(status: :updated, record: organization)
    end
  rescue ActiveRecord::StaleObjectError
    raise Error.new("This record changed. Reload it and try again.", code: :conflict)
  end

  private

  def cascade_dependents!(organization)
    affected = empty_affected
    today = agency_today

    organization.organization_contacts.current.order(:id).lock.each do |assignment|
      assignment.update!(ends_on: today, primary: false)
      affected["ended_assignment_ids"] << assignment.id
    end

    contact_point_scopes(organization).each do |type, scope|
      scope.order(:id).lock.each do |point|
        next if point.inactive? && !point.preferred?

        point.update!(status: "inactive", preferred: false)
        affected["inactivated_contact_points"] << { "type" => type, "id" => point.id }
      end
    end

    affected
  end

  def contact_point_scopes(organization)
    {
      "ClientOrganizationEmailAddress" => organization.email_addresses,
      "ClientOrganizationPhoneNumber" => organization.phone_numbers,
      "ClientOrganizationPostalAddress" => organization.postal_addresses,
      "ClientOrganizationWebsite" => organization.websites
    }
  end

  def empty_affected
    { "ended_assignment_ids" => [], "inactivated_contact_points" => [] }
  end
end
