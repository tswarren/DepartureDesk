class SupplierContactEmailAddressesController < SupplierContactOwnedDestinationsController
  private

  def contact_scope
    @supplier_contact.email_addresses
  end

  def create_command
    CreateSupplierContactEmailAddress
  end

  def update_command
    UpdateSupplierContactEmailAddress
  end

  def status_command
    ChangeSupplierContactEmailAddressStatus
  end

  def set_primary_command
    SetPreferredSupplierContactEmailAddress
  end

  def channel_label
    "Email address"
  end

  def contact_params
    params.expect(supplier_contact_email_address: %i[address label preferred lock_version])
  end
end
