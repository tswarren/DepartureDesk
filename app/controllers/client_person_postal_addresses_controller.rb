class ClientPersonPostalAddressesController < ClientPersonContactPointsController
  private

  def contact_scope
    @client_person.postal_addresses
  end

  def create_command
    CreateClientPersonPostalAddress
  end

  def update_command
    UpdateClientPersonPostalAddress
  end

  def status_command
    ChangeClientPersonPostalAddressStatus
  end

  def set_primary_command
    SetPreferredClientPersonPostalAddress
  end

  def channel_label
    "Postal address"
  end

  def contact_params
    params.expect(client_person_postal_address: %i[line_1 line_2 locality region postal_code country_code label preferred lock_version])
  end
end
