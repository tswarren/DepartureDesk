class SetPreferredClientOrganizationPostalAddress < ClientOrganizationContactPointCommand
  def call
    prepare!
    require_lock_version!
    ActiveRecord::Base.transaction do
      @agency.lock!
      organization = locked_organization
      point = organization.postal_addresses.find(@record.id)
      changed = apply_preferred!(organization.postal_addresses, point, true, lock_version: @lock_version)
      audit_contact!(organization, changed_fields: [ "preferred_postal_address" ]) if changed
      Result.new(status: changed ? :updated : :noop, record: point.reload)
    end
  rescue ActiveRecord::StaleObjectError
    raise Error.new("This record changed. Reload it and try again.", code: :conflict)
  end
end
