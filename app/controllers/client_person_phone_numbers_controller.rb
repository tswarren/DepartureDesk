class ClientPersonPhoneNumbersController < ClientPersonContactPointsController
  def new
    @contact_point = contact_scope.new(preferred: false, country_code: Current.agency.country_code)
  end

  private

  def contact_scope
    @client_person.phone_numbers
  end

  def create_command
    CreateClientPersonPhoneNumber
  end

  def update_command
    UpdateClientPersonPhoneNumber
  end

  def status_command
    ChangeClientPersonPhoneNumberStatus
  end

  def set_primary_command
    SetPreferredClientPersonPhoneNumber
  end

  def channel_label
    "Phone number"
  end

  def contact_params
    params.expect(client_person_phone_number: %i[number extension country_code label preferred lock_version])
  end
end
