class UpdateClientPersonEmailAddress < ClientPersonContactPointCommand
  COMMAND = "UpdateClientPersonEmailAddress"

  def call
    prepare!
    ActiveRecord::Base.transaction do
      @agency.lock!
      person = locked_person
      point = locked_channel_row(person.email_addresses, @record)
      point.lock_version = @lock_version
      address = @attributes[:address].to_s.strip
      preferred = ActiveModel::Type::Boolean.new.cast(@attributes[:preferred])
      identity_unchanged = point.address == address && point.label == @attributes[:label].presence
      return Result.new(status: :noop, record: point) if identity_unchanged && point.preferred? == preferred

      decision = nil
      unless identity_unchanged
        fingerprint = DuplicateAcknowledgement.fingerprint("address" => address.downcase)
        decision = DirectoryDuplicateGate.new(
          agency: @agency, actor: @actor, command: COMMAND, token: @acknowledgement_token,
          reason: @acknowledgement_reason, fingerprint: fingerprint, target: point,
          current_fingerprint: -> { DuplicateAcknowledgement.fingerprint("address" => point.address.to_s.downcase) }
        ).call { FindClientPersonDuplicates.call(agency: @agency, actor: @actor, names: {}, emails: [ address ], exclude_person_id: person.id) }
        return decision if decision.is_a?(Result)

        point.update!(address: address, label: @attributes[:label])
      end
      apply_preferred!(person.email_addresses, point, preferred, lock_version: identity_unchanged ? @lock_version : nil)
      audit_contact!(person, changed_fields: [ "email_address" ])
      audit_override!(person, decision) if decision
      Result.new(status: :updated, record: point)
    end
  rescue ActiveRecord::StaleObjectError
    raise Error.new("This record changed. Reload it and try again.", code: :conflict)
  rescue ActiveRecord::RecordInvalid => error
    raise Error.new(error.record.errors.full_messages.to_sentence, code: :invalid)
  end
end
