class UpdateClientPersonPhoneNumber < ClientPersonContactPointCommand
  COMMAND = "UpdateClientPersonPhoneNumber"

  def call
    prepare!
    ActiveRecord::Base.transaction do
      @agency.lock!
      person = locked_person
      point = person.phone_numbers.lock.find(@record.id)
      point.lock_version = @lock_version
      phone = PhoneNumberNormalizer.call(number: @attributes[:number], extension: @attributes[:extension], country_code: @attributes[:country_code])
      preferred = ActiveModel::Type::Boolean.new.cast(@attributes[:preferred])
      identity_unchanged = point.normalized_number == phone.normalized_number &&
        point.extension.to_s == phone.extension.to_s &&
        point.country_code == phone.country_code &&
        point.label == @attributes[:label].presence
      return Result.new(status: :noop, record: point) if identity_unchanged && point.preferred? == preferred

      decision = nil
      unless identity_unchanged
        fingerprint = DuplicateAcknowledgement.fingerprint("number" => phone.normalized_number, "extension" => phone.extension.to_s)
        decision = DirectoryDuplicateGate.new(
          agency: @agency, actor: @actor, command: COMMAND, token: @acknowledgement_token,
          reason: @acknowledgement_reason, fingerprint: fingerprint, target: point,
          current_fingerprint: -> { DuplicateAcknowledgement.fingerprint("number" => point.normalized_number, "extension" => point.extension.to_s) }
        ).call { FindClientPersonDuplicates.call(agency: @agency, actor: @actor, names: {}, phones: [ phone ], exclude_person_id: person.id) }
        return decision if decision.is_a?(Result)

        point.update!(number: phone.number, normalized_number: phone.normalized_number, extension: phone.extension, country_code: phone.country_code, label: @attributes[:label])
      end
      apply_preferred!(person.phone_numbers, point, preferred)
      audit_contact!(person, changed_fields: [ "phone_number" ])
      audit_override!(person) if decision
      Result.new(status: :updated, record: point)
    end
  rescue ActiveRecord::StaleObjectError
    raise Error.new("This record changed. Reload it and try again.", code: :conflict)
  rescue ActiveRecord::RecordInvalid => error
    raise Error.new(error.record.errors.full_messages.to_sentence, code: :invalid)
  end
end
