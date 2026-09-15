class CreateSupplierPhoneNumber < SupplierContactPointCommand
  COMMAND = "CreateSupplierPhoneNumber"

  def call
    prepare!
    ActiveRecord::Base.transaction do
      @agency.lock!
      supplier = locked_supplier
      raise Error.new("That supplier is not active.", code: :invalid_state) unless supplier.active?

      phone = PhoneNumberNormalizer.call(number: @attributes[:number], extension: @attributes[:extension], country_code: @attributes[:country_code])
      fingerprint = DuplicateAcknowledgement.fingerprint("number" => phone.normalized_number, "extension" => phone.extension.to_s)
      point_id = SecureRandom.uuid_v7
      decision = DirectoryDuplicateGate.new(
        agency: @agency, actor: @actor, command: COMMAND, token: @acknowledgement_token,
        reason: @acknowledgement_reason, fingerprint: fingerprint,
        proposed_ids: { "supplier_id" => supplier.id, "contact_point_id" => point_id, "contact_class" => "SupplierPhoneNumber" }
      ).call { FindSupplierDuplicates.call(agency: @agency, actor: @actor, kind: supplier.kind, names: {}, phones: [ phone ], exclude_supplier_id: supplier.id) }
      return decision if decision.is_a?(Result)

      point = supplier.phone_numbers.create!(
        id: decision&.dig("contact_point_id") || point_id,
        agency: @agency,
        number: phone.number,
        normalized_number: phone.normalized_number,
        extension: phone.extension,
        country_code: phone.country_code,
        label: @attributes[:label],
        preferred: false,
        status: "active"
      )
      prefer!(supplier.phone_numbers, point) if ActiveModel::Type::Boolean.new.cast(@attributes[:preferred])
      audit_contact!(supplier, record: point, changed_fields: [ "phone_number" ])
      audit_override!(supplier, decision) if decision
      Result.new(status: :created, record: point)
    end
  rescue ActiveRecord::RecordInvalid => error
    raise Error.new(error.record.errors.full_messages.to_sentence, code: :invalid)
  end
end
