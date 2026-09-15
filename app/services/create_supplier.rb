class CreateSupplier < AgencyCommand
  include SupplierReferenceIssuance

  COMMAND = "CreateSupplier"

  def initialize(agency:, actor:, kind:, names:, categories:, acknowledgement_token: nil, acknowledgement_reason: nil)
    @agency = agency
    @actor = actor
    @kind = kind.to_s
    @names = names.to_h.symbolize_keys
    @categories = categories
    @acknowledgement_token = acknowledgement_token
    @acknowledgement_reason = acknowledgement_reason
  end

  def call
    ensure_directory_actor!(@actor, @agency, :manage_supplier_directory)
    ensure_active_agency!(@agency)
    raise Error.new("Choose organization or individual.", code: :invalid) unless Supplier::KINDS.include?(@kind)

    ActiveRecord::Base.transaction do
      @agency.lock!
      supplier_id = SecureRandom.uuid_v7
      category_rows = normalized_category_rows
      decision = acknowledge!(supplier_id, category_rows)
      return decision if decision.is_a?(Result)

      supplier = @agency.suppliers.create!(
        id: decision&.dig("supplier_id") || supplier_id,
        kind: @kind,
        supplier_reference: issue_supplier_reference!(@agency),
        status: "active",
        **normalized_names
      )
      create_categories!(supplier, category_rows)
      audit!(agency: @agency, action: "supplier.created", subject: supplier, actor: @actor, details: { "supplier_id" => supplier.id, "category_codes" => category_rows.map { |row| row.fetch(:category_code) } })
      audit_override!(supplier, decision) if decision
      Result.new(status: :created, record: supplier)
    end
  rescue ActiveRecord::RecordInvalid => error
    raise Error.new(error.record.errors.full_messages.to_sentence, code: :invalid)
  rescue ArgumentError => error
    raise Error.new(error.message, code: :invalid)
  end

  private

  def acknowledge!(supplier_id, category_rows)
    DirectoryDuplicateGate.new(
      agency: @agency,
      actor: @actor,
      command: COMMAND,
      token: @acknowledgement_token,
      reason: @acknowledgement_reason,
      fingerprint: fingerprint(category_rows),
      proposed_ids: { "supplier_id" => supplier_id }
    ).call { candidates }
  end

  def candidates
    FindSupplierDuplicates.call(agency: @agency, actor: @actor, kind: @kind, names: normalized_names)
  end

  def normalized_names
    @normalized_names ||= begin
      values = {
        display_name: @names[:display_name].to_s.strip.presence,
        legal_name: @names[:legal_name].to_s.strip.presence,
        first_name: @names[:first_name].to_s.strip.presence,
        last_name: @names[:last_name].to_s.strip.presence,
        doing_business_as: @names[:doing_business_as].to_s.strip.presence
      }
      if @kind == "organization"
        values.merge(first_name: nil, last_name: nil)
      else
        values.merge(display_name: nil, legal_name: nil)
      end
    end
  end

  def normalized_category_rows
    rows = Array(@categories).filter_map do |entry|
      if entry.respond_to?(:to_h) && !entry.is_a?(String)
        attrs = entry.to_h.symbolize_keys
        code = attrs[:category_code] || attrs[:code]
        label = attrs[:other_label]
      else
        code = entry
        label = nil
      end
      code = code.to_s.strip.presence
      next if code.blank?

      { category_code: code, other_label: label.to_s.strip.presence }
    end

    codes = SupplierCategory.normalize_codes(rows.map { |row| row.fetch(:category_code) })
    raise Error.new("Choose at least one supplier category.", code: :invalid) if codes.empty?

    codes.map do |code|
      source = rows.reverse.find { |row| row.fetch(:category_code) == code } || {}
      label = source[:other_label]
      raise Error.new("Describe the other supplier category.", code: :invalid) if code == "other" && label.blank?
      raise Error.new("Other category label must be 80 characters or fewer.", code: :invalid) if label.to_s.length > 80
      raise Error.new("Only the other supplier category can have a label.", code: :invalid) if code != "other" && label.present?

      { category_code: code, other_label: code == "other" ? label : nil }
    end
  end

  def create_categories!(supplier, rows)
    rows.each do |row|
      supplier.category_assignments.create!(agency: @agency, **row)
    end
  end

  def fingerprint(category_rows)
    DuplicateAcknowledgement.fingerprint(
      normalized_names.transform_values { |value| SearchNormalizer.normalize(value) }
        .merge("kind" => @kind, "categories" => category_rows.map { |row| row.fetch(:category_code) })
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
