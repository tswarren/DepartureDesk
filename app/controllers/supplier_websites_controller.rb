class SupplierWebsitesController < SupplierContactPointsController
  private

  def contact_scope
    @supplier.websites
  end

  def create_command
    CreateSupplierWebsite
  end

  def update_command
    UpdateSupplierWebsite
  end

  def status_command
    ChangeSupplierWebsiteStatus
  end

  def set_primary_command
    SetPreferredSupplierWebsite
  end

  def channel_label
    "Website"
  end

  def contact_params
    params.expect(supplier_website: %i[url label preferred lock_version])
  end
end
