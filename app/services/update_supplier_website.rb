class UpdateSupplierWebsite < SupplierContactPointCommand
  COMMAND = "UpdateSupplierWebsite"

  def call
    prepare!
    ActiveRecord::Base.transaction do
      @agency.lock!
      supplier = locked_supplier
      point = locked_channel_row(supplier.websites, @record)
      require_matching_lock_version!(point)

      website = normalize_website!
      label = @attributes[:label].to_s.strip.presence
      preferred = ActiveModel::Type::Boolean.new.cast(@attributes[:preferred])
      changed = contact_changed_fields(
        point,
        url: website.url,
        normalized_url: website.normalized_url,
        normalized_host: website.normalized_host,
        label: label,
        preferred: preferred
      )
      return Result.new(status: :noop, record: point) if changed.empty?

      decision = nil
      if changed.intersect?(%w[url label])
        fingerprint = DuplicateAcknowledgement.fingerprint("normalized_host" => website.normalized_host)
        decision = DirectoryDuplicateGate.new(
          agency: @agency, actor: @actor, command: COMMAND, token: @acknowledgement_token,
          reason: @acknowledgement_reason, fingerprint: fingerprint, target: point,
          current_fingerprint: -> { DuplicateAcknowledgement.fingerprint("normalized_host" => point.normalized_host) }
        ).call { FindSupplierDuplicates.call(agency: @agency, actor: @actor, kind: supplier.kind, names: {}, websites: [ website ], exclude_supplier_id: supplier.id) }
        return decision if decision.is_a?(Result)

        point.update!(url: website.url, normalized_url: website.normalized_url, normalized_host: website.normalized_host, label: label)
      end
      apply_preferred!(supplier.websites, point, preferred) if changed.include?("preferred")
      audit_contact!(supplier, record: point.reload, changed_fields: changed)
      audit_override!(supplier, decision) if decision
      Result.new(status: :updated, record: point)
    end
  rescue ActiveRecord::StaleObjectError
    raise Error.new("This record changed. Reload it and try again.", code: :conflict)
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
