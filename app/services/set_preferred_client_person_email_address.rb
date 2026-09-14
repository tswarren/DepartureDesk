class SetPreferredClientPersonEmailAddress < ClientPersonContactPointCommand
  def call
    prepare!
    require_lock_version!
    ActiveRecord::Base.transaction do
      @agency.lock!
      person = locked_person
      point = person.email_addresses.find(@record.id)
      changed = apply_preferred!(person.email_addresses, point, true, lock_version: @lock_version)
      audit_contact!(person, changed_fields: [ "preferred_email_address" ]) if changed
      Result.new(status: changed ? :updated : :noop, record: point.reload)
    end
  rescue ActiveRecord::StaleObjectError
    raise Error.new("This record changed. Reload it and try again.", code: :conflict)
  end
end
