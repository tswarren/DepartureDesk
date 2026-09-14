class SetPreferredClientOrganizationWebsite < ClientOrganizationContactPointCommand
  def call
    prepare!
    require_lock_version!
    ActiveRecord::Base.transaction do
      @agency.lock!
      organization = locked_organization
      point = organization.websites.find(@record.id)
      changed = apply_preferred!(organization.websites, point, true, lock_version: @lock_version)
      audit_contact!(organization, changed_fields: [ "preferred_website" ]) if changed
      Result.new(status: changed ? :updated : :noop, record: point.reload)
    end
  rescue ActiveRecord::StaleObjectError
    raise Error.new("This record changed. Reload it and try again.", code: :conflict)
  end
end
