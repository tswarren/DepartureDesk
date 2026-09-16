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
      contractor = locked_supplier!(@pair.supplier_arrangement.contracting_supplier_id)
      departure, arrangement, version = lock_departure_arrangement_version!(@pair.supplier_arrangement)
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
      provider = effective_provider_for!(arrangement, item_definition, occurrence_definition)
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
        definition_attrs = submitted_definition_attrs.dup
        definition_attrs[:label] ||= generated_capacity_label(
          inventory_mode: inventory_mode,
          quantity: definition_attrs[:proposed_opening_quantity],
          unit_label: definition_attrs[:unit_label],
          siblings: siblings
        )
        definition_attrs[:normalized_label] = definition_attrs[:label].downcase.strip

        pool = arrangement.capacity_pools.create!(
          agency: @agency,
          departure: departure,
          arrangement_item: item,
          service_occurrence: occurrence,
          supplier_resource: resource,
          supplying_supplier: provider,
          inventory_mode: inventory_mode,
          measurement_basis: measurement_basis,
          effective_time_zone: occurrence_definition.time_zone
        )
        definition = version.capacity_pool_definitions.create!(
          definition_attrs.merge(
            agency: @agency,
            departure: departure,
            supplier_arrangement: arrangement,
            arrangement_item: item,
            service_occurrence: occurrence,
            supplier_resource: resource,
            capacity_pair_definition: pair,
            capacity_pool: pool,
            position: next_pool_position(version, pair)
          )
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
