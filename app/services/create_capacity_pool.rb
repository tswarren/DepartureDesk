class CreateCapacityPool < AgencyCommand
  include CapacityCommandSupport

  def initialize(agency:, actor:, pair:, attributes:, version_lock_version:, idempotency_key: nil)
    @agency = agency
    @actor = actor
    @pair = pair
    @attributes = attributes.to_h.with_indifferent_access
    @version_lock_version = version_lock_version
    @idempotency_key = idempotency_key || @attributes.delete(:idempotency_key)
  end

  def call
    ensure_arrangement_actor!
    inventory_mode = normalize_inventory_mode(@attributes[:inventory_mode])
    measurement_basis = normalize_measurement_basis(@attributes[:measurement_basis])
    submitted_definition_attrs = normalize_pool_definition_attributes(
      @attributes.merge(inventory_mode: inventory_mode),
      generate_label: false
    )

    ActiveRecord::Base.transaction do
      lock_authorized_arrangement_agency!
      arrangement = @agency.supplier_arrangements.find(@pair.supplier_arrangement_id)
      version = arrangement.versions.find_by!(status: "draft", version_number: 1)
      item_definition = version.arrangement_item_definitions.find_by!(arrangement_item_id: @pair.arrangement_item_id)
      occurrence_definition = version.service_occurrence_definitions.find_by!(
        arrangement_item_id: @pair.arrangement_item_id,
        service_occurrence_id: @pair.service_occurrence_id
      )
      provider_id = occurrence_definition.service_provider_id ||
        item_definition.default_service_provider_id ||
        arrangement.contracting_supplier_id
      locked_suppliers = lock_suppliers_in_uuid_order!(arrangement.contracting_supplier_id, provider_id).index_by(&:id)
      contractor = locked_suppliers.fetch(arrangement.contracting_supplier_id)
      departure, arrangement, version = lock_departure_arrangement_version!(arrangement)
      ensure_capacity_ordinary_edit!(departure, arrangement, version, contractor)
      pair = lock_pair_for!(version, @pair)
      ensure_pooled_pair!(pair)
      item = lock_arrangement_item_for!(arrangement, pair.arrangement_item)
      item_definition, occurrence, occurrence_definition, resource = lock_exact_capacity_graph!(
        version,
        item,
        pair.service_occurrence,
        pair.supplier_resource
      )
      ensure_managed_item!(item_definition)
      ensure_occurrence_accepts_capacity!(occurrence)
      resolved_provider_id = occurrence_definition.service_provider_id ||
        item_definition.default_service_provider_id ||
        arrangement.contracting_supplier_id
      unless locked_suppliers.key?(resolved_provider_id)
        raise Error.new("Service provider changed during capacity pool creation.", code: :conflict)
      end
      provider = locked_suppliers.fetch(resolved_provider_id)
      ensure_active_effective_provider!(provider)
      raise Error.new("Capacity pool time zone is incomplete.", code: :invalid) if occurrence_definition.time_zone.blank?

      idempotent_create!(
        command_name: self.class.name,
        idempotency_key: @idempotency_key,
        payload: submitted_definition_attrs.merge(
          supplier_arrangement_id: arrangement.id,
          supplier_arrangement_version_id: version.id,
          arrangement_item_id: item.id,
          capacity_pair_definition_id: pair.id,
          service_occurrence_id: occurrence.id,
          supplier_resource_id: resource.id,
          inventory_mode: inventory_mode,
          measurement_basis: measurement_basis,
          supplying_supplier_id: provider.id,
          effective_time_zone: occurrence_definition.time_zone
        ),
        result_class: CapacityPool
      ) do
        ensure_current_lock_version!(version, @version_lock_version)
        siblings = lock_current_pool_definitions_for!(version, pair)
        pool, definition = build_capacity_pool_already_locked!(
          departure: departure,
          arrangement: arrangement,
          version: version,
          item: item,
          occurrence: occurrence,
          resource: resource,
          pair: pair,
          provider: provider,
          inventory_mode: inventory_mode,
          measurement_basis: measurement_basis,
          effective_time_zone: occurrence_definition.time_zone,
          definition_attributes: submitted_definition_attrs,
          siblings: siblings
        )
        bump_version!(version)
        audit!(
          agency: @agency,
          action: "supplier_arrangement.capacity_pool_created",
          subject: arrangement,
          actor: @actor,
          details: {
            "supplier_arrangement_id" => arrangement.id,
            "supplier_arrangement_version_id" => version.id,
            "arrangement_item_id" => item.id,
            "capacity_pair_definition_id" => pair.id,
            "capacity_pool_id" => pool.id,
            "capacity_pool_definition_id" => definition.id,
            "service_occurrence_id" => occurrence.id,
            "supplier_resource_id" => resource.id,
            "supplying_supplier_id" => provider.id,
            "inventory_mode" => pool.inventory_mode,
            "measurement_basis" => pool.measurement_basis,
            "effective_time_zone" => pool.effective_time_zone,
            "label" => definition.label,
            "unit_label" => definition.unit_label,
            "proposed_opening_quantity" => definition.proposed_opening_quantity,
            "position" => definition.position,
            "evidence_kind" => definition.evidence_kind,
            "override" => definition.override?
          }
        )
        pool
      end
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  end
end
