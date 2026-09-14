class SetPreferredClientPersonPhoneNumber < ClientPersonContactPointCommand
  def call
    prepare!
    ActiveRecord::Base.transaction do
      @agency.lock!
      person = locked_person
      point = person.phone_numbers.lock.find(@record.id)
      apply_preferred!(person.phone_numbers, point, true)
      audit_contact!(person, changed_fields: [ "preferred_phone_number" ])
      Result.new(status: :updated, record: point)
    end
  end
end
