class ClientOrganizationPhoneNumbersController < ClientOrganizationContactPointsController
  def new
    @contact_point = contact_scope.new(preferred: false, country_code: Current.agency.country_code)
  end

  private

  def contact_scope
    @client_organization.phone_numbers
  end

  def create_command
    CreateClientOrganizationPhoneNumber
  end

  def update_command
    UpdateClientOrganizationPhoneNumber
  end

  def status_command
    ChangeClientOrganizationPhoneNumberStatus
  end

  def set_primary_command
    SetPreferredClientOrganizationPhoneNumber
  end

  def channel_label
    "Phone number"
  end

  def contact_params
    params.expect(client_organization_phone_number: %i[number extension country_code label preferred lock_version])
  end
end
