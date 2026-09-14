class ChangeClientOrganizationPhoneNumberStatus < ClientOrganizationContactPointCommand
  def call
    prepare!
    raise Error.new("Choose active or inactive.", code: :invalid) unless ClientOrganizationPhoneNumber::STATUSES.include?(@status)

    ActiveRecord::Base.transaction do
      @agency.lock!
      organization = locked_organization
      raise Error.new("That organization is not active.", code: :invalid_state) if @status == "active" && organization.inactive?
      point = organization.phone_numbers.lock.find(@record.id)
      return Result.new(status: :noop, record: point) if point.status == @status

      point.lock_version = @lock_version
      point.update!(status: @status, preferred: @status == "active" ? point.preferred : false)
      audit_contact!(organization, changed_fields: [ "phone_number_status" ])
      Result.new(status: :updated, record: point)
    end
  rescue ActiveRecord::StaleObjectError
    raise Error.new("This record changed. Reload it and try again.", code: :conflict)
  end
end
