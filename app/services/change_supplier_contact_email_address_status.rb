class ChangeSupplierContactEmailAddressStatus < SupplierContactDestinationCommand
  def call
    prepare!
    raise Error.new("Choose active or inactive.", code: :invalid) unless SupplierContactEmailAddress::STATUSES.include?(@status)

    ActiveRecord::Base.transaction do
      @agency.lock!
      supplier = locked_supplier
      contact = locked_contact(supplier)
      raise Error.new("That supplier is not active.", code: :invalid_state) if @status == "active" && supplier.inactive?
      raise Error.new("That supplier contact is not active.", code: :invalid_state) if @status == "active" && contact.inactive?
      point = locked_channel_row(contact.email_addresses, @record)
      require_matching_lock_version!(point) if point.status == @status
      return Result.new(status: :noop, record: point) if point.status == @status

      point.lock_version = @lock_version
      point.update!(status: @status, preferred: @status == "active" ? point.preferred : false)
      audit_contact!(contact, record: point, changed_fields: [ "email_address_status" ])
      Result.new(status: :updated, record: point)
    end
  rescue ActiveRecord::StaleObjectError
    raise Error.new("This record changed. Reload it and try again.", code: :conflict)
  end
end
