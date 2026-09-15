class UpdateSupplierPostalAddress < SupplierContactPointCommand
  COMMAND = "UpdateSupplierPostalAddress"

  def call
    prepare!
    ActiveRecord::Base.transaction do
      @agency.lock!
      supplier = locked_supplier
      point = locked_channel_row(supplier.postal_addresses, @record)
      point.lock_version = @lock_version
      raise Error.new("Enter an accepted country.", code: :invalid) unless CountryCode.accepted?(@attributes[:country_code])

      preferred = ActiveModel::Type::Boolean.new.cast(@attributes[:preferred])
      identity_unchanged = unchanged?(point)
      require_matching_lock_version!(point) if identity_unchanged && point.preferred? == preferred
      return Result.new(status: :noop, record: point) if identity_unchanged && point.preferred? == preferred

      decision = nil
      unless identity_unchanged
        decision = DirectoryDuplicateGate.new(
          agency: @agency, actor: @actor, command: COMMAND, token: @acknowledgement_token,
          reason: @acknowledgement_reason, fingerprint: postal_fingerprint, target: point,
          current_fingerprint: -> { stored_fingerprint(point) }
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

        point.update!(postal_attributes)
      end
      apply_preferred!(supplier.postal_addresses, point, preferred, lock_version: identity_unchanged ? @lock_version : nil)
      audit_contact!(supplier, record: point, changed_fields: [ "postal_address" ])
      audit_override!(supplier, decision) if decision
      Result.new(status: :updated, record: point)
    end
  rescue ActiveRecord::StaleObjectError
    raise Error.new("This record changed. Reload it and try again.", code: :conflict)
  rescue ActiveRecord::RecordInvalid => error
    raise Error.new(error.record.errors.full_messages.to_sentence, code: :invalid)
  end

  private

  def unchanged?(point)
    postal_attributes.all? { |key, value| point.public_send(key).presence == value.presence }
  end

  def postal_attributes
    @postal_attributes ||= @attributes.slice(:line_1, :line_2, :locality, :region, :postal_code, :country_code, :label)
  end

  def postal_fingerprint
    DuplicateAcknowledgement.fingerprint(
      "line_1" => SearchNormalizer.normalize(@attributes[:line_1]),
      "postal_code" => SearchNormalizer.normalize(@attributes[:postal_code]),
      "country_code" => @attributes[:country_code].to_s.upcase
    )
  end

  def stored_fingerprint(point)
    DuplicateAcknowledgement.fingerprint(
      "line_1" => SearchNormalizer.normalize(point.line_1),
      "postal_code" => SearchNormalizer.normalize(point.postal_code),
      "country_code" => point.country_code.to_s
    )
  end
end
