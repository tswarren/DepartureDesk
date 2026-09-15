class SupplierContactPhoneNumbersController < SupplierContactOwnedDestinationsController
  def new
    @contact_point = contact_scope.new(preferred: false, country_code: Current.agency.country_code)
  end

  private

  def contact_scope
    @supplier_contact.phone_numbers
  end

  def create_command
    CreateSupplierContactPhoneNumber
  end

  def update_command
    UpdateSupplierContactPhoneNumber
  end

  def status_command
    ChangeSupplierContactPhoneNumberStatus
  end

  def set_primary_command
    SetPreferredSupplierContactPhoneNumber
  end

  def channel_label
    "Phone number"
  end

  def contact_params
    params.expect(supplier_contact_phone_number: %i[number extension country_code label preferred lock_version])
  end
end
