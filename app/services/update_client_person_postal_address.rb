class UpdateClientPersonPostalAddress < ClientPersonContactPointCommand
  COMMAND = "UpdateClientPersonPostalAddress"

  def call
    prepare!
    ActiveRecord::Base.transaction do
      @agency.lock!
      person = locked_person
      point = locked_channel_row(person.postal_addresses, @record)
      point.lock_version = @lock_version
      raise Error.new("Enter an accepted country.", code: :invalid) unless CountryCode.accepted?(@attributes[:country_code])

      preferred = ActiveModel::Type::Boolean.new.cast(@attributes[:preferred])
      identity_unchanged = point.line_1 == @attributes[:line_1].to_s.strip.presence &&
        point.line_2 == @attributes[:line_2].to_s.strip.presence &&
        point.locality == @attributes[:locality].to_s.strip.presence &&
        point.region == @attributes[:region].to_s.strip.presence &&
        point.postal_code == @attributes[:postal_code].to_s.strip.presence &&
        point.country_code == @attributes[:country_code].to_s.upcase &&
        point.label == @attributes[:label].presence
      return Result.new(status: :noop, record: point) if identity_unchanged && point.preferred? == preferred

      decision = nil
      unless identity_unchanged
        fingerprint = DuplicateAcknowledgement.fingerprint(
          "line_1" => SearchNormalizer.normalize(@attributes[:line_1]),
          "postal_code" => SearchNormalizer.normalize(@attributes[:postal_code]),
          "country_code" => @attributes[:country_code].to_s.upcase
        )
        decision = DirectoryDuplicateGate.new(
          agency: @agency, actor: @actor, command: COMMAND, token: @acknowledgement_token,
          reason: @acknowledgement_reason, fingerprint: fingerprint, target: point,
          current_fingerprint: -> { DuplicateAcknowledgement.fingerprint("line_1" => SearchNormalizer.normalize(point.line_1), "postal_code" => SearchNormalizer.normalize(point.postal_code), "country_code" => point.country_code.to_s) }
        ).call do
          FindClientPersonDuplicates.call(agency: @agency, actor: @actor, names: person.slice(:first_name, :middle_name, :last_name, :suffix), postal_codes: [ @attributes[:postal_code] ], exclude_person_id: person.id)
        end
        return decision if decision.is_a?(Result)

        point.update!(line_1: @attributes[:line_1], line_2: @attributes[:line_2], locality: @attributes[:locality], region: @attributes[:region], postal_code: @attributes[:postal_code], country_code: @attributes[:country_code], label: @attributes[:label])
      end
      apply_preferred!(person.postal_addresses, point, preferred, lock_version: identity_unchanged ? @lock_version : nil)
      audit_contact!(person, changed_fields: [ "postal_address" ])
      audit_override!(person, decision) if decision
      Result.new(status: :updated, record: point)
    end
  rescue ActiveRecord::StaleObjectError
    raise Error.new("This record changed. Reload it and try again.", code: :conflict)
  rescue ActiveRecord::RecordInvalid => error
    raise Error.new(error.record.errors.full_messages.to_sentence, code: :invalid)
  end
end
