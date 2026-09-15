class CreateSupplierPostalAddress < SupplierContactPointCommand
  COMMAND = "CreateSupplierPostalAddress"

  def call
    prepare!
    ActiveRecord::Base.transaction do
      @agency.lock!
      supplier = locked_supplier
      raise Error.new("That supplier is not active.", code: :invalid_state) unless supplier.active?
      raise Error.new("Enter an accepted country.", code: :invalid) unless CountryCode.accepted?(@attributes[:country_code])

      point_id = SecureRandom.uuid_v7
      decision = DirectoryDuplicateGate.new(
        agency: @agency, actor: @actor, command: COMMAND, token: @acknowledgement_token,
        reason: @acknowledgement_reason, fingerprint: postal_fingerprint,
        proposed_ids: { "supplier_id" => supplier.id, "contact_point_id" => point_id, "contact_class" => "SupplierPostalAddress" }
      ).call do
        FindSupplierDuplicates.call(
          agency: @agency,
          actor: @actor,
          kind: supplier.kind,
          names: supplier_duplicate_names(supplier),
          postal_codes: [ @attributes[:postal_code] ],
          localities: [ @attributes[:locality] ],
          exclude_supplier_id: supplier.id
        )
      end
      return decision if decision.is_a?(Result)

      point = supplier.postal_addresses.create!(
        id: decision&.dig("contact_point_id") || point_id,
        agency: @agency,
        **postal_attributes,
        preferred: false,
        status: "active"
      )
      prefer!(supplier.postal_addresses, point) if ActiveModel::Type::Boolean.new.cast(@attributes[:preferred])
      audit_contact!(supplier, record: point, changed_fields: [ "postal_address" ])
      audit_override!(supplier, decision) if decision
      Result.new(status: :created, record: point)
    end
  rescue ActiveRecord::RecordInvalid => error
    raise Error.new(error.record.errors.full_messages.to_sentence, code: :invalid)
  end

  private

  def postal_attributes
    @attributes.slice(:line_1, :line_2, :locality, :region, :postal_code, :country_code, :label)
  end

  def postal_fingerprint
    DuplicateAcknowledgement.fingerprint(
      "line_1" => SearchNormalizer.normalize(@attributes[:line_1]),
      "postal_code" => SearchNormalizer.normalize(@attributes[:postal_code]),
      "country_code" => @attributes[:country_code].to_s.upcase
    )
  end
end
