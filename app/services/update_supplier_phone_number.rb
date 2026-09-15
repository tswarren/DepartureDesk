class UpdateSupplierPhoneNumber < SupplierContactPointCommand
  COMMAND = "UpdateSupplierPhoneNumber"

  def call
    prepare!
    ActiveRecord::Base.transaction do
      @agency.lock!
      supplier = locked_supplier
      point = locked_channel_row(supplier.phone_numbers, @record)
      require_matching_lock_version!(point)

      phone = PhoneNumberNormalizer.call(number: @attributes[:number], extension: @attributes[:extension], country_code: @attributes[:country_code])
      label = @attributes[:label].to_s.strip.presence
      preferred = ActiveModel::Type::Boolean.new.cast(@attributes[:preferred])
      changed = contact_changed_fields(
        point,
        number: phone.number,
        normalized_number: phone.normalized_number,
        extension: phone.extension,
        country_code: phone.country_code,
        label: label,
        preferred: preferred
      )
      return Result.new(status: :noop, record: point) if changed.empty?

      decision = nil
      if changed.intersect?(%w[number extension country_code label])
        fingerprint = DuplicateAcknowledgement.fingerprint("number" => phone.normalized_number, "extension" => phone.extension.to_s)
        decision = DirectoryDuplicateGate.new(
          agency: @agency, actor: @actor, command: COMMAND, token: @acknowledgement_token,
          reason: @acknowledgement_reason, fingerprint: fingerprint, target: point,
          current_fingerprint: -> { DuplicateAcknowledgement.fingerprint("number" => point.normalized_number, "extension" => point.extension.to_s) }
        ).call { FindSupplierDuplicates.call(agency: @agency, actor: @actor, kind: supplier.kind, names: {}, phones: [ phone ], exclude_supplier_id: supplier.id) }
        return decision if decision.is_a?(Result)

        point.update!(
          number: phone.number,
          normalized_number: phone.normalized_number,
          extension: phone.extension,
          country_code: phone.country_code,
          label: label
        )
      end
      apply_preferred!(supplier.phone_numbers, point, preferred) if changed.include?("preferred")
      audit_contact!(supplier, record: point.reload, changed_fields: changed)
      audit_override!(supplier, decision) if decision
      Result.new(status: :updated, record: point)
    end
  rescue ActiveRecord::StaleObjectError
    raise Error.new("This record changed. Reload it and try again.", code: :conflict)
  rescue ActiveRecord::RecordInvalid => error
    raise Error.new(error.record.errors.full_messages.to_sentence, code: :invalid)
  end
end
