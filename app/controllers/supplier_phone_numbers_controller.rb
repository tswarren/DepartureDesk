class SupplierPhoneNumbersController < SupplierContactPointsController
  def new
    @contact_point = contact_scope.new(preferred: false, country_code: Current.agency.country_code)
  end

  private

  def contact_scope
    @supplier.phone_numbers
  end

  def create_command
    CreateSupplierPhoneNumber
  end

  def update_command
    UpdateSupplierPhoneNumber
  end

  def status_command
    ChangeSupplierPhoneNumberStatus
  end

  def set_primary_command
    SetPreferredSupplierPhoneNumber
  end

  def channel_label
    "Phone number"
  end

  def contact_params
    params.expect(supplier_phone_number: %i[number extension country_code label preferred lock_version])
  end
end
