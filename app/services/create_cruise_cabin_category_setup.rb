# frozen_string_literal: true

class CreateCruiseCabinCategorySetup < AgencyCommand
  include CapacityCommandSupport

  SetupResult = Data.define(:resource, :pool)

  def initialize(agency:, actor:, arrangement:, resource_attributes:, pool_attributes:,
    version_lock_version:, idempotency_key:)
    @agency = agency
    @actor = actor
    @arrangement = arrangement
    @resource_attributes = resource_attributes.to_h.with_indifferent_access
    @pool_attributes = pool_attributes.to_h.with_indifferent_access
    @version_lock_version = version_lock_version
    @idempotency_key = idempotency_key
  end

  def call
    ensure_arrangement_actor!
    resource_attrs = normalize_resource_attributes(@resource_attributes)
    inventory_mode = normalize_inventory_mode(@pool_attributes[:inventory_mode])
    measurement_basis = "resource_units"
    pool_input = @pool_attributes.merge(
      inventory_mode: inventory_mode,
      unit_label: "cabins"
    )
    ensure_numeric_quantity_when_required!(inventory_mode, pool_input[:proposed_opening_quantity])

    ActiveRecord::Base.transaction do
      lock_authorized_arrangement_agency!
      arrangement = @agency.supplier_arrangements.find(@arrangement.id)
      version = arrangement.versions.find_by!(status: "draft")
      item_definition = version.arrangement_item_definitions.sole
      occurrence_definition = version.service_occurrence_definitions.sole
      unless item_definition.category == "cruise"
        raise Error.new("That arrangement is not a Cruise sailing setup.", code: :invalid_state)
      end

      provider_id = occurrence_definition.service_provider_id ||
        item_definition.default_service_provider_id ||
        arrangement.contracting_supplier_id
      suppliers = lock_suppliers_in_uuid_order!(
        arrangement.contracting_supplier_id, provider_id
      ).index_by(&:id)
      contractor = suppliers.fetch(arrangement.contracting_supplier_id)

      departure, arrangement, version = lock_departure_arrangement_version!(arrangement)
      item = lock_arrangement_item_for!(arrangement, item_definition.arrangement_item)
      ensure_capacity_ordinary_edit!(departure, arrangement, version, contractor)
      item_definition = lock_item_definition_for!(version, item_definition)
      occurrence = lock_occurrence_for!(item, occurrence_definition.service_occurrence)
      occurrence_definition = lock_occurrence_definition_for!(version, occurrence_definition)
      ensure_managed_item!(item_definition)
      ensure_occurrence_accepts_capacity!(occurrence)
      raise Error.new("Capacity pool time zone is incomplete.", code: :invalid) if occurrence_definition.time_zone.blank?

      provider = suppliers.fetch(
        occurrence_definition.service_provider_id ||
          item_definition.default_service_provider_id ||
          arrangement.contracting_supplier_id
      )
      ensure_active_effective_provider!(provider)

      submitted_definition_attrs = normalize_pool_definition_attributes(
        pool_input,
        generate_label: false
      )
      ensure_numeric_quantity_when_required!(
        inventory_mode,
        submitted_definition_attrs[:proposed_opening_quantity]
      )

      payload = submitted_definition_attrs.merge(
        supplier_arrangement_id: arrangement.id,
        supplier_arrangement_version_id: version.id,
        arrangement_item_id: item.id,
        service_occurrence_id: occurrence.id,
        resource: resource_attrs,
        classification: "pooled",
        inventory_mode: inventory_mode,
        measurement_basis: measurement_basis,
        supplying_supplier_id: provider.id,
        effective_time_zone: occurrence_definition.time_zone,
        unit_label: "cabins"
      )

      result = idempotent_create!(
        command_name: self.class.name,
        idempotency_key: @idempotency_key,
        payload: payload,
        result_class: CapacityPool
      ) do
        ensure_current_lock_version!(version, @version_lock_version)
        resource, resource_definition = build_supplier_resource_already_locked!(
          departure: departure,
          arrangement: arrangement,
          version: version,
          item: item,
          attributes: resource_attrs
        )
        pair = lock_pair_by_members!(version, occurrence, resource)
        if pair&.capacity_pool_definitions&.exists?
          raise Error.new("This capacity pair already has a Pool.", code: :invalid_state)
        end
        pair, previous, pair_status = classify_capacity_pair_already_locked!(
          departure: departure,
          arrangement: arrangement,
          version: version,
          item: item,
          occurrence: occurrence,
          resource: resource,
          classification: "pooled",
          pair: pair
        )
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
          action: "supplier_arrangement.capacity_pair_pool_configured",
          subject: arrangement,
          actor: @actor,
          details: {
            "supplier_arrangement_id" => arrangement.id,
            "supplier_arrangement_version_id" => version.id,
            "arrangement_item_id" => item.id,
            "capacity_pair_definition_id" => pair.id,
            "capacity_pair_status" => pair_status.to_s,
            "previous_classification" => previous,
            "classification" => pair.classification,
            "capacity_pool_id" => pool.id,
            "capacity_pool_definition_id" => definition.id,
            "service_occurrence_id" => occurrence.id,
            "supplier_resource_id" => resource.id,
            "supplier_resource_definition_id" => resource_definition.id,
            "supplying_supplier_id" => provider.id,
            "inventory_mode" => pool.inventory_mode,
            "measurement_basis" => pool.measurement_basis,
            "effective_time_zone" => pool.effective_time_zone,
            "label" => definition.label,
            "unit_label" => definition.unit_label,
            "proposed_opening_quantity" => definition.proposed_opening_quantity,
            "position" => definition.position,
            "evidence_kind" => definition.evidence_kind,
            "override" => definition.override?,
            "supplier_code" => resource_definition.supplier_code,
            "maximum_occupancy" => resource_definition.maximum_occupancy
          }
        )
        pool
      end

      AgencyCommand::Result.new(
        status: result.status,
        record: setup_result_for(result.record)
      )
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  rescue ActiveRecord::RecordNotFound, Enumerable::SoleItemExpectedError
    raise Error.new("That arrangement is not a Cruise sailing setup.", code: :invalid_state)
  end

  private

  def ensure_numeric_quantity_when_required!(inventory_mode, quantity)
    return unless %w[block allotment].include?(inventory_mode)
    return if quantity.present?

    raise Error.new("Enter a cabin quantity.", code: :invalid)
  end

  def setup_result_for(pool)
    SetupResult.new(resource: pool.supplier_resource, pool: pool)
  end
end
