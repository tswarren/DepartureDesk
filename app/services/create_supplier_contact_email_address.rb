class CreateSupplierContactEmailAddress < SupplierContactDestinationCommand
  COMMAND = "CreateSupplierContactEmailAddress"

  def call
    prepare!
    ActiveRecord::Base.transaction do
      @agency.lock!
      supplier = locked_supplier
      contact = locked_contact(supplier)
      raise Error.new("That supplier is not active.", code: :invalid_state) unless supplier.active?
      raise Error.new("That supplier contact is not active.", code: :invalid_state) unless contact.active?

      address = @attributes[:address].to_s.strip
      fingerprint = DuplicateAcknowledgement.fingerprint("address" => address.downcase)
      point_id = SecureRandom.uuid_v7
      decision = DirectoryDuplicateGate.new(
        agency: @agency,
        actor: @actor,
        command: COMMAND,
        token: @acknowledgement_token,
        reason: @acknowledgement_reason,
        fingerprint: fingerprint,
        proposed_ids: {
          "supplier_id" => supplier.id,
          "supplier_contact_id" => contact.id,
          "contact_point_id" => point_id,
          "contact_class" => "SupplierContactEmailAddress"
        }
      ).call do
        FindSupplierContactDuplicates.call(
          agency: @agency,
          actor: @actor,
          supplier: supplier,
          first_name: nil,
          last_name: nil,
          emails: [ address ],
          exclude_contact_id: contact.id
        )
      end
      return decision if decision.is_a?(Result)

      point = contact.email_addresses.create!(
        id: decision&.dig("contact_point_id") || point_id,
        agency: @agency,
        address: address,
        label: @attributes[:label],
        preferred: false,
        status: "active"
      )
      prefer!(contact.email_addresses, point) if ActiveModel::Type::Boolean.new.cast(@attributes[:preferred])
      audit_contact!(contact, record: point, changed_fields: [ "email_address" ])
      audit_override!(contact, decision) if decision
      Result.new(status: :created, record: point)
    end
  rescue ActiveRecord::RecordInvalid => error
    raise Error.new(error.record.errors.full_messages.to_sentence, code: :invalid)
  end
end
