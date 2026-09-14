class ChangeClientPersonPostalAddressStatus < ClientPersonContactPointCommand
  def call
    prepare!
    raise Error.new("Choose active or inactive.", code: :invalid) unless ClientPersonPostalAddress::STATUSES.include?(@status)

    ActiveRecord::Base.transaction do
      @agency.lock!
      person = locked_person
      raise Error.new("That person is not active.", code: :invalid_state) if @status == "active" && person.inactive?
      point = person.postal_addresses.lock.find(@record.id)
      return Result.new(status: :noop, record: point) if point.status == @status

      point.lock_version = @lock_version
      point.update!(status: @status, preferred: @status == "active" ? point.preferred : false)
      audit_contact!(person, changed_fields: [ "postal_address_status" ])
      Result.new(status: :updated, record: point)
    end
  rescue ActiveRecord::StaleObjectError
    raise Error.new("This record changed. Reload it and try again.", code: :conflict)
  end
end
