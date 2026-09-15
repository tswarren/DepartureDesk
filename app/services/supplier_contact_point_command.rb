class SupplierContactPointCommand < AgencyCommand
  def initialize(agency:, actor:, supplier:, record: nil, attributes: {}, lock_version: nil, acknowledgement_token: nil, acknowledgement_reason: nil, status: nil)
    @agency = agency
    @actor = actor
    @supplier = supplier
    @record = record
    @attributes = attributes.to_h.symbolize_keys
    @lock_version = lock_version
    @acknowledgement_token = acknowledgement_token
    @acknowledgement_reason = acknowledgement_reason
    @status = status
  end

  private

  def prepare!
    ensure_directory_actor!(@actor, @agency, :manage_supplier_directory)
    ensure_active_agency!(@agency)
    raise Error.new("That supplier could not be found.", code: :invalid) unless @supplier&.agency_id == @agency.id
  end

  def locked_supplier
    @locked_supplier ||= @agency.suppliers.lock.find(@supplier.id)
  end

  def supplier_duplicate_names(supplier)
    {
      display_name: supplier.display_name,
      legal_name: supplier.legal_name,
      first_name: supplier.first_name,
      last_name: supplier.last_name,
      doing_business_as: supplier.doing_business_as
    }
  end

  def audit_contact!(supplier, record:, changed_fields:)
    audit!(
      agency: @agency,
      action: "supplier.contact_updated",
      subject: supplier,
      actor: @actor,
      details: {
        "supplier_id" => supplier.id,
        "contact_point_id" => record.id,
        "contact_point_type" => record.class.name,
        "changed_fields" => changed_fields
      }
    )
  end

  def apply_preferred!(scope, point, preferred, lock_version: nil)
    preferred = ActiveModel::Type::Boolean.new.cast(preferred)
    current = locked_channel_row(scope, point)
    if lock_version && current.lock_version != lock_version.to_i
      raise ActiveRecord::StaleObjectError.new(current, "lock_version")
    end
    return false if current.preferred? == preferred
    raise Error.new("Only an active record can be preferred.", code: :invalid_state) if preferred && !current.active?

    if preferred
      locked_channel_rows(scope).each do |row|
        next unless row.preferred? && row.id != current.id

        row.update!(preferred: false)
      end
    end
    current.update!(preferred: preferred)
    true
  end

  def require_lock_version!
    raise Error.new("This record changed. Reload it and try again.", code: :conflict) if @lock_version.nil?
  end

  def require_matching_lock_version!(record)
    require_lock_version!
    return if record.lock_version == @lock_version.to_i

    raise ActiveRecord::StaleObjectError.new(record, "lock_version")
  end

  def locked_channel_row(scope, record)
    locked_channel_rows(scope).find { |row| row.id == record.id } || raise(ActiveRecord::RecordNotFound)
  end

  def locked_channel_rows(scope)
    scope.order(:id).lock.to_a
  end

  def prefer!(scope, point)
    scope.where.not(id: point.id).update_all(preferred: false, updated_at: Time.current)
    point.update!(preferred: true)
  end

  def audit_override!(supplier, decision = nil)
    audit!(
      agency: @agency,
      action: "supplier.duplicate_override",
      subject: supplier,
      actor: @actor,
      details: duplicate_override_details(decision, reason: @acknowledgement_reason)
    )
  end
end
