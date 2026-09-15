class CreateSupplierContact < AgencyCommand
  COMMAND = "CreateSupplierContact"

  def initialize(agency:, actor:, supplier:, attributes:, acknowledgement_token: nil, acknowledgement_reason: nil)
    @agency = agency
    @actor = actor
    @supplier = supplier
    @attributes = attributes.to_h.symbolize_keys
    @acknowledgement_token = acknowledgement_token
    @acknowledgement_reason = acknowledgement_reason
  end

  def call
    ensure_directory_actor!(@actor, @agency, :manage_supplier_directory)
    ensure_active_agency!(@agency)
    raise ActiveRecord::RecordNotFound if @supplier.blank?

    ActiveRecord::Base.transaction do
      contact_id = SecureRandom.uuid_v7
      @agency.lock!
      supplier = @agency.suppliers.lock.find(@supplier.id)
      raise Error.new("That supplier is not active.", code: :invalid_state) unless supplier.active?

      attrs = normalized_attributes
      decision = acknowledge!(supplier, contact_id, attrs)
      return decision if decision.is_a?(Result)

      contact = supplier.contacts.create!(
        id: decision&.dig("supplier_contact_id") || contact_id,
        agency: @agency,
        **attrs,
        preferred: false,
        status: "active"
      )
      audit!(
        agency: @agency,
        action: "supplier_contact.created",
        subject: contact,
        actor: @actor,
        details: { "supplier_contact_id" => contact.id, "supplier_id" => supplier.id }
      )
      audit_override!(contact, decision) if decision
      Result.new(status: :created, record: contact)
    end
  rescue ActiveRecord::RecordInvalid => error
    raise Error.new(error.record.errors.full_messages.to_sentence, code: :invalid)
  end

  private

  def acknowledge!(supplier, contact_id, attrs)
    DirectoryDuplicateGate.new(
      agency: @agency,
      actor: @actor,
      command: COMMAND,
      token: @acknowledgement_token,
      reason: @acknowledgement_reason,
      fingerprint: fingerprint(attrs),
      proposed_ids: { "supplier_contact_id" => contact_id, "supplier_id" => supplier.id }
    ).call { candidates(supplier, attrs) }
  end

  def candidates(supplier, attrs)
    FindSupplierContactDuplicates.call(
      agency: @agency,
      actor: @actor,
      supplier: supplier,
      first_name: attrs[:first_name],
      last_name: attrs[:last_name]
    )
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

  def fingerprint(attrs)
    DuplicateAcknowledgement.fingerprint(
      "first_name" => SearchNormalizer.normalize(attrs[:first_name]),
      "last_name" => SearchNormalizer.normalize(attrs[:last_name])
    )
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
