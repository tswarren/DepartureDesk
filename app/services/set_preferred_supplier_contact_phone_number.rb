class SetPreferredSupplierContactPhoneNumber < SupplierContactDestinationCommand
  def call
    prepare!
    require_lock_version!
    ActiveRecord::Base.transaction do
      @agency.lock!
      supplier = locked_supplier
      contact = locked_contact(supplier)
      point = contact.phone_numbers.find(@record.id)
      changed = apply_preferred!(contact.phone_numbers, point, true, lock_version: @lock_version)
      audit_contact!(contact, record: point, changed_fields: [ "preferred_phone_number" ]) if changed
      Result.new(status: changed ? :updated : :noop, record: point.reload)
    end
  rescue ActiveRecord::StaleObjectError
    raise Error.new("This record changed. Reload it and try again.", code: :conflict)
  end
end
