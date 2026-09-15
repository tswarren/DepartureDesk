class SetPreferredSupplierContactEmailAddress < SupplierContactDestinationCommand
  def call
    prepare!
    require_lock_version!
    ActiveRecord::Base.transaction do
      @agency.lock!
      supplier = locked_supplier
      contact = locked_contact(supplier)
      point = contact.email_addresses.find(@record.id)
      changed = apply_preferred!(contact.email_addresses, point, true, lock_version: @lock_version)
      audit_contact!(contact, record: point, changed_fields: [ "preferred_email_address" ]) if changed
      Result.new(status: changed ? :updated : :noop, record: point.reload)
    end
  rescue ActiveRecord::StaleObjectError
    raise Error.new("This record changed. Reload it and try again.", code: :conflict)
  end
end
