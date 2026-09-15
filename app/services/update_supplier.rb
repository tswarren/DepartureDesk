class UpdateSupplier < AgencyCommand
  COMMAND = "UpdateSupplier"

  def initialize(agency:, actor:, supplier:, names:, lock_version:, acknowledgement_token: nil, acknowledgement_reason: nil)
    @agency = agency
    @actor = actor
    @supplier = supplier
    @names = names.to_h.symbolize_keys
    @lock_version = lock_version
    @acknowledgement_token = acknowledgement_token
    @acknowledgement_reason = acknowledgement_reason
  end

  def call
    ensure_directory_actor!(@actor, @agency, :manage_supplier_directory)
    ensure_active_agency!(@agency)

    ActiveRecord::Base.transaction do
      @agency.lock!
      supplier = @agency.suppliers.lock.find(@supplier.id)
      raise ActiveRecord::StaleObjectError.new(supplier, "lock_version") if @lock_version.nil?
      raise ActiveRecord::StaleObjectError.new(supplier, "lock_version") if supplier.lock_version != @lock_version.to_i
      supplier.lock_version = @lock_version
      attrs = normalized_names_for(supplier.kind)
      return Result.new(status: :noop, record: supplier) if unchanged?(supplier, attrs)

      decision = acknowledge!(supplier, attrs)
      return decision if decision.is_a?(Result)

      supplier.update!(attrs)
      audit!(agency: @agency, action: "supplier.updated", subject: supplier, actor: @actor, details: { "supplier_id" => supplier.id, "changed_fields" => changed_fields(supplier, attrs) })
      audit_override!(supplier, decision) if decision
      Result.new(status: :updated, record: supplier)
    end
  rescue ActiveRecord::StaleObjectError
    raise Error.new("This record changed. Reload it and try again.", code: :conflict)
  rescue ActiveRecord::RecordInvalid => error
    raise Error.new(error.record.errors.full_messages.to_sentence, code: :invalid)
  end

  private

  def acknowledge!(supplier, attrs)
    DirectoryDuplicateGate.new(
      agency: @agency,
      actor: @actor,
      command: COMMAND,
      token: @acknowledgement_token,
      reason: @acknowledgement_reason,
      fingerprint: fingerprint(supplier.kind, attrs),
      target: supplier,
      current_fingerprint: -> { stored_fingerprint(supplier) }
    ).call { FindSupplierDuplicates.call(agency: @agency, actor: @actor, kind: supplier.kind, names: attrs, exclude_supplier_id: supplier.id) }
  end

  def normalized_names_for(kind)
    values = {
      display_name: @names[:display_name].to_s.strip.presence,
      legal_name: @names[:legal_name].to_s.strip.presence,
      first_name: @names[:first_name].to_s.strip.presence,
      last_name: @names[:last_name].to_s.strip.presence,
      doing_business_as: @names[:doing_business_as].to_s.strip.presence
    }
    kind == "organization" ? values.merge(first_name: nil, last_name: nil) : values.merge(display_name: nil, legal_name: nil)
  end

  def unchanged?(supplier, attrs)
    attrs.all? { |key, value| supplier.public_send(key).presence == value.presence }
  end

  def changed_fields(supplier, attrs)
    attrs.keys.select { |key| supplier.saved_change_to_attribute?(key) }.map(&:to_s)
  end

  def fingerprint(kind, attrs)
    DuplicateAcknowledgement.fingerprint(attrs.transform_values { |value| SearchNormalizer.normalize(value) }.merge("kind" => kind))
  end

  def stored_fingerprint(supplier)
    fingerprint(
      supplier.kind,
      %i[display_name legal_name first_name last_name doing_business_as].index_with { |key| supplier.public_send(key) }
    )
  end

  def audit_override!(supplier, decision)
    audit!(
      agency: @agency,
      action: "supplier.duplicate_override",
      subject: supplier,
      actor: @actor,
      details: duplicate_override_details(decision, reason: @acknowledgement_reason)
    )
  end
end
