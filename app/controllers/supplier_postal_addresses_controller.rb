class SupplierPostalAddressesController < SupplierContactPointsController
  private

  def contact_scope
    @supplier.postal_addresses
  end

  def create_command
    CreateSupplierPostalAddress
  end

  def update_command
    UpdateSupplierPostalAddress
  end

  def status_command
    ChangeSupplierPostalAddressStatus
  end

  def set_primary_command
    SetPreferredSupplierPostalAddress
  end

  def channel_label
    "Postal address"
  end

  def contact_params
    params.expect(supplier_postal_address: %i[line_1 line_2 locality region postal_code country_code label preferred lock_version])
  end
end
