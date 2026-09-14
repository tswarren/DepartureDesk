class SetPreferredClientPersonEmailAddress < ClientPersonContactPointCommand
  def call
    prepare!
    ActiveRecord::Base.transaction do
      @agency.lock!
      person = locked_person
      point = person.email_addresses.lock.find(@record.id)
      apply_preferred!(person.email_addresses, point, true)
      audit_contact!(person, changed_fields: [ "preferred_email_address" ])
      Result.new(status: :updated, record: point)
    end
  end
end
