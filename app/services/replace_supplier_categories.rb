class ReplaceSupplierCategories < AgencyCommand
  def initialize(agency:, actor:, supplier:, categories:, lock_version:)
    @agency = agency
    @actor = actor
    @supplier = supplier
    @categories = categories
    @lock_version = lock_version
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
      existing = supplier.category_assignments.order(:id).lock.to_a
      rows = normalized_category_rows

      old_codes = existing.map(&:category_code).sort
      new_codes = rows.map { |row| row.fetch(:category_code) }
      other_label_changed = other_label(existing) != other_label(rows)
      return Result.new(status: :noop, record: supplier) if old_codes == new_codes && !other_label_changed

      reconcile!(supplier, existing, rows)
      supplier.touch
      audit!(
        agency: @agency,
        action: "supplier.categories_changed",
        subject: supplier,
        actor: @actor,
        details: {
          "supplier_id" => supplier.id,
          "old_category_codes" => old_codes,
          "new_category_codes" => new_codes,
          "other_label_changed" => other_label_changed
        }
      )
      Result.new(status: :updated, record: supplier)
    end
  rescue ActiveRecord::StaleObjectError
    raise Error.new("This record changed. Reload it and try again.", code: :conflict)
  rescue ActiveRecord::RecordInvalid => error
    raise Error.new(error.record.errors.full_messages.to_sentence, code: :invalid)
  rescue ArgumentError => error
    raise Error.new(error.message, code: :invalid)
  end

  private

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

  def reconcile!(supplier, existing, rows)
    by_code = existing.index_by(&:category_code)
    rows.each do |row|
      assignment = by_code[row.fetch(:category_code)]
      if assignment
        assignment.update!(other_label: row.fetch(:other_label)) if assignment.other_label != row.fetch(:other_label)
      else
        supplier.category_assignments.create!(agency: @agency, **row)
      end
    end

    keep_codes = rows.map { |row| row.fetch(:category_code) }
    existing.reject { |assignment| keep_codes.include?(assignment.category_code) }.each(&:destroy!)
  end

  def other_label(records)
    if records.first.is_a?(Hash)
      records.find { |row| row.fetch(:category_code) == "other" }&.fetch(:other_label)
    else
      records.find { |row| row.category_code == "other" }&.other_label
    end
  end
end
