class ClientOrganizationPostalAddressesController < ClientOrganizationContactPointsController
  private

  def contact_scope
    @client_organization.postal_addresses
  end

  def create_command
    CreateClientOrganizationPostalAddress
  end

  def update_command
    UpdateClientOrganizationPostalAddress
  end

  def status_command
    ChangeClientOrganizationPostalAddressStatus
  end

  def set_primary_command
    SetPreferredClientOrganizationPostalAddress
  end

  def channel_label
    "Postal address"
  end

  def contact_params
    params.expect(client_organization_postal_address: %i[line_1 line_2 locality region postal_code country_code label preferred lock_version])
  end
end
