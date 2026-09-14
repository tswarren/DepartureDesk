class ClientOrganizationEmailAddressesController < ClientOrganizationContactPointsController
  private

  def contact_scope
    @client_organization.email_addresses
  end

  def create_command
    CreateClientOrganizationEmailAddress
  end

  def update_command
    UpdateClientOrganizationEmailAddress
  end

  def status_command
    ChangeClientOrganizationEmailAddressStatus
  end

  def set_primary_command
    SetPreferredClientOrganizationEmailAddress
  end

  def channel_label
    "Email address"
  end

  def contact_params
    params.expect(client_organization_email_address: %i[address label preferred lock_version])
  end
end
