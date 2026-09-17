module ReservationCommandSupport
  extend ActiveSupport::Concern

  include ArrangementCommandSupport

  private

  def resolve_reservation_version!(arrangement, explicit_version = nil)
    scope = arrangement.versions
    version = if explicit_version.present?
      scope.find_by(id: explicit_version.respond_to?(:id) ? explicit_version.id : explicit_version)
    elsif arrangement.active?
      arrangement.governing_version
    else
      scope.find_by(status: "draft")
    end
    raise ActiveRecord::RecordNotFound if version.nil?

    version
  end

  def ensure_reservation_planning_state!(departure, arrangement, version, booking_supplier)
    unless departure.draft? || departure.active?
      raise AgencyCommand::Error.new("A departed departure cannot create supplier reservation planning.", code: :invalid_state)
    end
    unless (arrangement.draft? && version.draft?) || (arrangement.active? && (version.draft? || arrangement.governing_version_id == version.id))
      raise AgencyCommand::Error.new("That arrangement version cannot receive reservation planning.", code: :invalid_state)
    end
    unless booking_supplier.active?
      raise AgencyCommand::Error.new("The booking supplier is not active.", code: :invalid_state)
    end
  end

  def resolve_booking_supplier!(arrangement, version, supplier_id)
    supplier = locked_supplier!(supplier_id.presence || arrangement.contracting_supplier_id)
    eligible_ids = eligible_booking_supplier_ids(arrangement, version)
    unless eligible_ids.include?(supplier.id)
      raise AgencyCommand::Error.new("Choose the contracting supplier or an effective provider for this version.", code: :invalid)
    end
    supplier
  end

  def eligible_booking_supplier_ids(arrangement, version)
    ids = [ arrangement.contracting_supplier_id ]
    item_provider_by_id = version.arrangement_item_definitions.pluck(:arrangement_item_id, :default_service_provider_id).to_h
    ids.concat(item_provider_by_id.values)
    version.service_occurrence_definitions.find_each do |definition|
      ids << (definition.service_provider_id || item_provider_by_id[definition.arrangement_item_id] || arrangement.contracting_supplier_id)
    end
    ids.compact.uniq
  end

  def normalize_scopes!(arrangement, version, raw_scopes)
    values = Array(raw_scopes).filter_map do |_key, value|
      next unless value.respond_to?(:to_h)

      hash = value.to_h
      hash if hash.values.any?(&:present?)
    end
    if raw_scopes.is_a?(Array)
      values = raw_scopes.select do |value|
        value.respond_to?(:to_h) && value.to_h.values.any?(&:present?)
      end
    end
    values = [ { target_kind: "arrangement" } ] if values.empty?

    scopes = values.each_with_index.map do |value, index|
      attrs = value.to_h.with_indifferent_access
      normalize_scope!(arrangement, version, attrs, index + 1)
    end
    raise AgencyCommand::Error.new("Add at least one reservation scope.", code: :invalid) if scopes.empty?

    scopes
  end

  def normalize_scope!(arrangement, version, attrs, position)
    target_kind = attrs[:target_kind].to_s.strip.presence || "arrangement"
    unless SupplierReservationScope::TARGET_KINDS.include?(target_kind)
      raise AgencyCommand::Error.new("Choose a valid reservation scope.", code: :invalid)
    end

    item_id = parse_optional_uuid(attrs[:arrangement_item_id], "Arrangement Item")
    occurrence_id = parse_optional_uuid(attrs[:service_occurrence_id], "Service Occurrence")
    resource_id = parse_optional_uuid(attrs[:supplier_resource_id], "Supplier Resource")
    pool_id = parse_optional_uuid(attrs[:capacity_pool_id], "Capacity Pool")

    case target_kind
    when "arrangement"
      item_id = occurrence_id = resource_id = pool_id = nil
    when "item"
      item = arrangement.arrangement_items.find(item_id)
      ensure_item_defined!(version, item.id)
      occurrence_id = resource_id = pool_id = nil
    when "occurrence"
      occurrence = arrangement.service_occurrences.find(occurrence_id)
      item_id = occurrence.arrangement_item_id
      ensure_occurrence_defined!(version, item_id, occurrence.id)
      resource_id = pool_id = nil
    when "resource"
      resource = arrangement.supplier_resources.find(resource_id)
      item_id = resource.arrangement_item_id
      ensure_resource_defined!(version, item_id, resource.id)
      occurrence_id = pool_id = nil
    when "capacity_pool"
      pool = arrangement.capacity_pools.find(pool_id)
      item_id = pool.arrangement_item_id
      occurrence_id = pool.service_occurrence_id
      resource_id = pool.supplier_resource_id
      ensure_capacity_pool_defined!(version, item_id, occurrence_id, resource_id, pool.id)
    end

    quantity = normalize_optional_positive_integer(attrs[:requested_quantity], "Requested quantity")
    basis = attrs[:quantity_basis].to_s.strip.presence
    if quantity.present?
      unless SupplierReservationScope::QUANTITY_BASES.include?(basis)
        raise AgencyCommand::Error.new("Choose a valid quantity basis.", code: :invalid)
      end
      if target_kind == "capacity_pool"
        pool_basis = CapacityPool.find(pool_id).measurement_basis
        unless basis == pool_basis
          raise AgencyCommand::Error.new("Requested quantity basis must match the Capacity Pool.", code: :invalid)
        end
      end
    elsif basis.present?
      raise AgencyCommand::Error.new("Quantity basis requires a requested quantity.", code: :invalid)
    end

    {
      position: position,
      target_kind: target_kind,
      arrangement_item_id: item_id,
      service_occurrence_id: occurrence_id,
      supplier_resource_id: resource_id,
      capacity_pool_id: pool_id,
      label: attrs[:label].to_s.strip.presence,
      requested_quantity: quantity,
      quantity_basis: basis
    }
  end

  def normalize_optional_positive_integer(value, label)
    return nil if value.blank?

    integer = Integer(value)
    raise ArgumentError if integer <= 0

    integer
  rescue ArgumentError, TypeError
    raise AgencyCommand::Error.new("#{label} must be a positive whole number.", code: :invalid)
  end

  def ensure_item_defined!(version, item_id)
    version.arrangement_item_definitions.find_by!(arrangement_item_id: item_id)
  end

  def ensure_occurrence_defined!(version, item_id, occurrence_id)
    version.service_occurrence_definitions.find_by!(
      arrangement_item_id: item_id, service_occurrence_id: occurrence_id
    )
  end

  def ensure_resource_defined!(version, item_id, resource_id)
    version.supplier_resource_definitions.find_by!(
      arrangement_item_id: item_id, supplier_resource_id: resource_id
    )
  end

  def ensure_capacity_pool_defined!(version, item_id, occurrence_id, resource_id, pool_id)
    version.capacity_pool_definitions.find_by!(
      arrangement_item_id: item_id,
      service_occurrence_id: occurrence_id,
      supplier_resource_id: resource_id,
      capacity_pool_id: pool_id
    )
  end

  def reservation_owner(reservation, version = nil)
    {
      agency: @agency,
      departure_id: reservation.departure_id,
      supplier_arrangement_id: reservation.supplier_arrangement_id,
      supplier_arrangement_version_id: version&.id,
      supplier_reservation: reservation
    }.compact
  end

  def scope_fingerprint(scopes)
    payload_digest(scopes.map do |scope|
      {
        id: scope.id,
        target_kind: scope.target_kind,
        arrangement_item_id: scope.arrangement_item_id,
        service_occurrence_id: scope.service_occurrence_id,
        supplier_resource_id: scope.supplier_resource_id,
        capacity_pool_id: scope.capacity_pool_id,
        requested_quantity: scope.requested_quantity,
        quantity_basis: scope.quantity_basis
      }
    end)
  end

  def latest_outcomes_by_scope(revision)
    SupplierReservationEventScopeOutcome
      .where(supplier_reservation_revision_id: revision.id)
      .order(:created_at, :id)
      .group_by(&:supplier_reservation_scope_id)
      .transform_values(&:last)
  end
end
