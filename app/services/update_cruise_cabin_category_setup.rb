# frozen_string_literal: true

class UpdateCruiseCabinCategorySetup < AgencyCommand
  include CapacityCommandSupport

  SetupResult = Data.define(:resource_definition, :pool_definition)

  def initialize(agency:, actor:, arrangement:, resource:, resource_attributes:,
    pool_attributes:, version_lock_version:, resource_lock_version:, pool_lock_version:)
    @agency = agency
    @actor = actor
    @arrangement = arrangement
    @resource = resource
    @resource_attributes = resource_attributes.to_h.with_indifferent_access
    @pool_attributes = pool_attributes.to_h.with_indifferent_access
    @version_lock_version = version_lock_version
    @resource_lock_version = resource_lock_version
    @pool_lock_version = pool_lock_version
  end

  def call
    ensure_arrangement_actor!
    reject_immutable_pool_identity_mutations!

    ActiveRecord::Base.transaction do
      lock_authorized_arrangement_agency!
      contractor = locked_supplier!(@arrangement.contracting_supplier_id)
      departure, arrangement, version = lock_departure_arrangement_version!(@arrangement)
      ensure_capacity_ordinary_edit!(departure, arrangement, version, contractor)
      ensure_current_lock_version!(version, @version_lock_version)

      item_definition = version.arrangement_item_definitions.sole
      occurrence_definition = version.service_occurrence_definitions.sole
      unless item_definition.category == "cruise"
        raise Error.new("That arrangement is not a Cruise sailing setup.", code: :invalid_state)
      end

      item = lock_arrangement_item_for!(arrangement, item_definition.arrangement_item)
      occurrence = lock_occurrence_for!(item, occurrence_definition.service_occurrence)
      resource = lock_resource_for!(item, @resource)
      resource_definition = version.supplier_resource_definitions.lock.find_by!(
        arrangement_item: item,
        supplier_resource: resource
      )
      ensure_current_lock_version!(resource_definition, @resource_lock_version)

      pool = arrangement.capacity_pools.lock.find_by!(
        arrangement_item: item,
        service_occurrence: occurrence,
        supplier_resource: resource
      )
      pool_definition = version.capacity_pool_definitions.lock.find_by!(capacity_pool: pool)
      ensure_current_lock_version!(pool_definition, @pool_lock_version)

      resource_attrs = normalize_resource_attributes(
        @resource_attributes.merge(
          description: @resource_attributes.fetch(:description, resource_definition.description)
        )
      )
      pool_attrs = normalize_pool_definition_update_attributes(
        @pool_attributes.merge(
          unit_label: pool_definition.unit_label,
          inventory_mode: pool.inventory_mode
        ),
        pool_definition
      )

      unchanged =
        same_values?(resource_definition, resource_attrs) &&
        same_values?(pool_definition, pool_attrs)
      if unchanged
        return Result.new(
          status: :noop,
          record: SetupResult.new(
            resource_definition: resource_definition,
            pool_definition: pool_definition
          )
        )
      end

      resource_definition.update!(resource_attrs) unless same_values?(resource_definition, resource_attrs)
      pool_definition.update!(pool_attrs) unless same_values?(pool_definition, pool_attrs)
      bump_version!(version)

      audit!(
        agency: @agency,
        action: "supplier_arrangement.capacity_pool_updated",
        subject: arrangement,
        actor: @actor,
        details: {
          "supplier_arrangement_id" => arrangement.id,
          "supplier_arrangement_version_id" => version.id,
          "arrangement_item_id" => item.id,
          "capacity_pair_definition_id" => pool_definition.capacity_pair_definition_id,
          "capacity_pool_id" => pool.id,
          "capacity_pool_definition_id" => pool_definition.id,
          "supplier_resource_id" => resource.id,
          "supplier_resource_definition_id" => resource_definition.id,
          "supplying_supplier_id" => pool.supplying_supplier_id,
          "inventory_mode" => pool.inventory_mode,
          "measurement_basis" => pool.measurement_basis,
          "changed_fields" => capacity_definition_changed_fields(pool_definition, pool_attrs),
          "resource_changed_fields" => changed_fields(resource_definition, resource_attrs),
          "label" => pool_definition.label,
          "unit_label" => pool_definition.unit_label,
          "proposed_opening_quantity" => pool_definition.proposed_opening_quantity,
          "evidence_kind" => pool_definition.evidence_kind,
          "override" => pool_definition.override?,
          "supplier_code" => resource_definition.supplier_code,
          "maximum_occupancy" => resource_definition.maximum_occupancy
        }
      )

      Result.new(
        status: :updated,
        record: SetupResult.new(
          resource_definition: resource_definition,
          pool_definition: pool_definition
        )
      )
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  rescue ActiveRecord::RecordNotFound, Enumerable::SoleItemExpectedError
    raise Error.new("That cabin category setup is not available.", code: :invalid_state)
  end

  private

  def reject_immutable_pool_identity_mutations!
    {
      inventory_mode: "Inventory mode",
      measurement_basis: "Measurement basis",
      effective_time_zone: "Effective time zone",
      supplying_supplier_id: "Supplying supplier"
    }.each do |key, label|
      next unless @pool_attributes.key?(key)

      raise Error.new(
        "#{label} cannot be changed on the typed Cruise cabin form. Use advanced Supplier planning to remove and recreate the Pool.",
        code: :invalid
      )
    end
  end
end
