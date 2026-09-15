class CreateSupplierEmailAddress < SupplierContactPointCommand
  COMMAND = "CreateSupplierEmailAddress"

  def call
    prepare!
    ActiveRecord::Base.transaction do
      @agency.lock!
      supplier = locked_supplier
      raise Error.new("That supplier is not active.", code: :invalid_state) unless supplier.active?

      address = @attributes[:address].to_s.strip
      fingerprint = DuplicateAcknowledgement.fingerprint("address" => address.downcase)
      point_id = SecureRandom.uuid_v7
      decision = DirectoryDuplicateGate.new(
        agency: @agency, actor: @actor, command: COMMAND, token: @acknowledgement_token,
        reason: @acknowledgement_reason, fingerprint: fingerprint,
        proposed_ids: { "supplier_id" => supplier.id, "contact_point_id" => point_id, "contact_class" => "SupplierEmailAddress" }
      ).call { FindSupplierDuplicates.call(agency: @agency, actor: @actor, kind: supplier.kind, names: {}, emails: [ address ], exclude_supplier_id: supplier.id) }
      return decision if decision.is_a?(Result)

      point = supplier.email_addresses.create!(
        id: decision&.dig("contact_point_id") || point_id,
        agency: @agency,
        address: address,
        label: @attributes[:label],
        preferred: false,
        status: "active"
      )
      prefer!(supplier.email_addresses, point) if ActiveModel::Type::Boolean.new.cast(@attributes[:preferred])
      audit_contact!(supplier, record: point, changed_fields: [ "email_address" ])
      audit_override!(supplier, decision) if decision
      Result.new(status: :created, record: point)
    end
  rescue ActiveRecord::RecordInvalid => error
    raise Error.new(error.record.errors.full_messages.to_sentence, code: :invalid)
  end
end
