class UpdateSupplierContact < AgencyCommand
  COMMAND = "UpdateSupplierContact"
  NAME_FIELDS = %i[first_name last_name].freeze

  def initialize(agency:, actor:, supplier:, supplier_contact:, attributes:, lock_version:, acknowledgement_token: nil, acknowledgement_reason: nil)
    @agency = agency
    @actor = actor
    @supplier = supplier
    @supplier_contact = supplier_contact
    @attributes = attributes.to_h.symbolize_keys
    @lock_version = lock_version
    @acknowledgement_token = acknowledgement_token
    @acknowledgement_reason = acknowledgement_reason
  end

  def call
    ensure_directory_actor!(@actor, @agency, :manage_supplier_directory)
    ensure_active_agency!(@agency)
    raise ActiveRecord::RecordNotFound if @supplier.blank? || @supplier_contact.blank?

    ActiveRecord::Base.transaction do
      @agency.lock!
      supplier = @agency.suppliers.lock.find(@supplier.id)
      contact = supplier.contacts.lock.find(@supplier_contact.id)
      raise ActiveRecord::StaleObjectError.new(contact, "lock_version") if @lock_version.nil?
      raise ActiveRecord::StaleObjectError.new(contact, "lock_version") if contact.lock_version != @lock_version.to_i
      contact.lock_version = @lock_version

      attrs = normalized_attributes
      return Result.new(status: :noop, record: contact) if unchanged?(contact, attrs)

      decision = nil
      if name_changed?(contact, attrs)
        decision = acknowledge!(supplier, contact, attrs)
        return decision if decision.is_a?(Result)
      end

      contact.update!(attrs)
      audit!(
        agency: @agency,
        action: "supplier_contact.updated",
        subject: contact,
        actor: @actor,
        details: {
          "supplier_contact_id" => contact.id,
          "supplier_id" => supplier.id,
          "changed_fields" => changed_fields(contact, attrs)
        }
      )
      audit_override!(contact, decision) if decision
      Result.new(status: :updated, record: contact)
    end
  rescue ActiveRecord::StaleObjectError
    raise Error.new("This record changed. Reload it and try again.", code: :conflict)
  rescue ActiveRecord::RecordInvalid => error
    raise Error.new(error.record.errors.full_messages.to_sentence, code: :invalid)
  end

  private

  def acknowledge!(supplier, contact, attrs)
    DirectoryDuplicateGate.new(
      agency: @agency,
      actor: @actor,
      command: COMMAND,
      token: @acknowledgement_token,
      reason: @acknowledgement_reason,
      fingerprint: fingerprint(attrs),
      target: contact,
      current_fingerprint: -> { stored_fingerprint(contact) }
    ).call do
      FindSupplierContactDuplicates.call(
        agency: @agency,
        actor: @actor,
        supplier: supplier,
        first_name: attrs[:first_name],
        last_name: attrs[:last_name],
        exclude_contact_id: contact.id
      )
    end
  end

  def normalized_attributes
    {
      first_name: @attributes[:first_name].to_s.strip.presence,
      last_name: @attributes[:last_name].to_s.strip.presence,
      title: @attributes[:title].to_s.strip.presence,
      department: @attributes[:department].to_s.strip.presence,
      role_label: @attributes[:role_label].to_s.strip.presence
    }
  end

  def unchanged?(contact, attrs)
    attrs.all? { |key, value| contact.public_send(key).presence == value.presence }
  end

  def name_changed?(contact, attrs)
    NAME_FIELDS.any? { |key| contact.public_send(key).presence != attrs[key].presence }
  end

  def changed_fields(contact, attrs)
    attrs.keys.select { |key| contact.saved_change_to_attribute?(key) }.map(&:to_s)
  end

  def fingerprint(attrs)
    DuplicateAcknowledgement.fingerprint(
      "first_name" => SearchNormalizer.normalize(attrs[:first_name]),
      "last_name" => SearchNormalizer.normalize(attrs[:last_name])
    )
  end

  def stored_fingerprint(contact)
    fingerprint(NAME_FIELDS.index_with { |key| contact.public_send(key) })
  end

  def audit_override!(contact, decision)
    audit!(
      agency: @agency,
      action: "supplier_contact.duplicate_override",
      subject: contact,
      actor: @actor,
      details: duplicate_override_details(decision, reason: @acknowledgement_reason)
    )
  end
end
