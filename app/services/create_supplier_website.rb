class CreateSupplierWebsite < SupplierContactPointCommand
  COMMAND = "CreateSupplierWebsite"

  def call
    prepare!
    ActiveRecord::Base.transaction do
      @agency.lock!
      supplier = locked_supplier
      raise Error.new("That supplier is not active.", code: :invalid_state) unless supplier.active?

      website = normalize_website!
      fingerprint = DuplicateAcknowledgement.fingerprint("normalized_host" => website.normalized_host)
      point_id = SecureRandom.uuid_v7
      decision = DirectoryDuplicateGate.new(
        agency: @agency, actor: @actor, command: COMMAND, token: @acknowledgement_token,
        reason: @acknowledgement_reason, fingerprint: fingerprint,
        proposed_ids: { "supplier_id" => supplier.id, "contact_point_id" => point_id, "contact_class" => "SupplierWebsite" }
      ).call { FindSupplierDuplicates.call(agency: @agency, actor: @actor, kind: supplier.kind, names: {}, websites: [ website ], exclude_supplier_id: supplier.id) }
      return decision if decision.is_a?(Result)

      point = supplier.websites.create!(
        id: decision&.dig("contact_point_id") || point_id,
        agency: @agency,
        url: website.url,
        normalized_url: website.normalized_url,
        normalized_host: website.normalized_host,
        label: @attributes[:label],
        preferred: false,
        status: "active"
      )
      prefer!(supplier.websites, point) if ActiveModel::Type::Boolean.new.cast(@attributes[:preferred])
      audit_contact!(supplier, record: point, changed_fields: [ "website" ])
      audit_override!(supplier, decision) if decision
      Result.new(status: :created, record: point)
    end
  rescue ActiveRecord::RecordInvalid => error
    raise Error.new(error.record.errors.full_messages.to_sentence, code: :invalid)
  end

  private

  def normalize_website!
    WebsiteNormalizer.call(url: @attributes[:url]).tap do |website|
      raise Error.new(website.error, code: :invalid) if website.error
    end
  end
end
