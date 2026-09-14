class SetPreferredClientPersonPostalAddress < ClientPersonContactPointCommand
  def call
    prepare!
    ActiveRecord::Base.transaction do
      @agency.lock!
      person = locked_person
      point = person.postal_addresses.lock.find(@record.id)
      apply_preferred!(person.postal_addresses, point, true)
      audit_contact!(person, changed_fields: [ "preferred_postal_address" ])
      Result.new(status: :updated, record: point)
    end
  end
end
