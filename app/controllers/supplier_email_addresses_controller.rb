class SupplierEmailAddressesController < SupplierContactPointsController
  private

  def contact_scope
    @supplier.email_addresses
  end

  def create_command
    CreateSupplierEmailAddress
  end

  def update_command
    UpdateSupplierEmailAddress
  end

  def status_command
    ChangeSupplierEmailAddressStatus
  end

  def set_primary_command
    SetPreferredSupplierEmailAddress
  end

  def channel_label
    "Email address"
  end

  def contact_params
    params.expect(supplier_email_address: %i[address label preferred lock_version])
  end
end
