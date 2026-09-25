# frozen_string_literal: true

class AddHotelRoomCategory < AgencyCommand
  include ArrangementCommandSupport
  include CapacityCommandSupport

  Result = Data.define(:resource, :pool)

  def initialize(agency:, actor:, arrangement:, attributes:, version_lock_version:, idempotency_key:)
    @agency = agency
    @actor = actor
    @arrangement = arrangement
    @attributes = attributes.to_h.with_indifferent_access
    @version_lock_version = version_lock_version
    @idempotency_key = idempotency_key
  end

  def call
    ensure_arrangement_actor!
    resource_attrs = normalize_resource_attributes(@attributes)
    quantity = @attributes[:quantity].presence

    ActiveRecord::Base.transaction do
      lock_authorized_arrangement_agency!
      arrangement = lock_arrangement_for!(@arrangement)
      version = arrangement.versions.find_by(status: "draft")
      raise Error.new("Open a successor draft before adding a room category.", code: :invalid_state) unless version

      item_definition = version.arrangement_item_definitions.where(category: "lodging").sole
      item = item_definition.arrangement_item
      occurrence_definition = version.service_occurrence_definitions.find_by!(arrangement_item_id: item.id)
      departure = lock_departure_for!(arrangement.departure)
      result = idempotent_create!(
        command_name: self.class.name, idempotency_key: @idempotency_key,
        payload: { supplier_arrangement_version_id: version.id, resource: resource_attrs, quantity: quantity },
        result_class: quantity ? CapacityPool : SupplierResource
      ) do
        ensure_current_lock_version!(version, @version_lock_version)
        resource, = build_supplier_resource_already_locked!(
          departure: departure, arrangement: arrangement, version: version, item: item, attributes: resource_attrs
        )
        pool = quantity ? configure_pool!(departure, arrangement, version, item, item_definition, occurrence_definition, resource, quantity) : nil
        bump_version!(version)
        audit!(
          agency: @agency, action: "supplier_arrangement.typed_item_setup", subject: arrangement, actor: @actor,
          details: {
            "supplier_arrangement_id" => arrangement.id, "arrangement_item_id" => item.id,
            "supplier_resource_id" => resource.id, "capacity_pool_id" => pool&.id
          }
        )
        quantity ? pool : resource
      end
      record = result.record
      AgencyCommand::Result.new(
        status: result.status,
        record: Result.new(
          resource: quantity ? record.supplier_resource : record,
          pool: quantity ? record : nil
        )
      )
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  end

  private

  def configure_pool!(departure, arrangement, version, item, item_definition, occurrence_definition, resource, quantity)
    item_definition.update!(capacity_management: "managed") unless item_definition.managed?
    occurrence = occurrence_definition.service_occurrence
    provider_id = occurrence_definition.service_provider_id || item_definition.default_service_provider_id || arrangement.contracting_supplier_id
    provider = @agency.suppliers.find(provider_id)
    pair = lock_pair_by_members!(version, occurrence, resource)
    pair, = classify_capacity_pair_already_locked!(
      departure: departure, arrangement: arrangement, version: version, item: item,
      occurrence: occurrence, resource: resource, classification: "pooled", pair: pair
    )
    submitted = normalize_pool_definition_attributes(
      { inventory_mode: "block", unit_label: "rooms", proposed_opening_quantity: quantity, label: resource.name },
      generate_label: false
    )
    pool, = build_capacity_pool_already_locked!(
      departure: departure, arrangement: arrangement, version: version, item: item,
      occurrence: occurrence, resource: resource, pair: pair, provider: provider,
      inventory_mode: "block", measurement_basis: "resource_units",
      effective_time_zone: occurrence_definition.time_zone,
      definition_attributes: submitted, siblings: []
    )
    pool
  end
end
