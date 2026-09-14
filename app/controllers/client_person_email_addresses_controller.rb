class ClientPersonEmailAddressesController < ClientPersonContactPointsController
  private

  def contact_scope
    @client_person.email_addresses
  end

  def create_command
    CreateClientPersonEmailAddress
  end

  def update_command
    UpdateClientPersonEmailAddress
  end

  def status_command
    ChangeClientPersonEmailAddressStatus
  end

  def set_primary_command
    SetPreferredClientPersonEmailAddress
  end

  def channel_label
    "Email address"
  end

  def contact_params
    params.expect(client_person_email_address: %i[address label preferred lock_version])
  end
end
