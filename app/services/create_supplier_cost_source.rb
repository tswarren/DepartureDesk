class CreateSupplierCostSource < AgencyCommand
  include CostCommandSupport

  def initialize(agency:, actor:, arrangement:, attributes:, version_lock_version:, idempotency_key: nil)
    @agency, @actor, @arrangement = agency, actor, arrangement
    @attributes = attributes.to_h.with_indifferent_access
    @version_lock_version = version_lock_version
    @idempotency_key = idempotency_key || @attributes.delete(:idempotency_key)
  end

  def call
    ensure_arrangement_actor!
    safely_command do
      ActiveRecord::Base.transaction do
        lock_authorized_arrangement_agency!
        charging_id = required_uuid(@attributes[:charging_supplier_id], "Charging supplier")
        departure, arrangement, version, contractor = cost_graph!(
          @arrangement, extra_supplier_ids: [ charging_id ]
        )
        suppliers = lock_suppliers_in_uuid_order!(arrangement.contracting_supplier_id, charging_id).index_by(&:id)
        contractor = suppliers.fetch(arrangement.contracting_supplier_id)
        charging_supplier = suppliers.fetch(charging_id)
        item, occurrence, resource = lock_item_cost_context!(
          arrangement, version, item: @attributes[:arrangement_item_id],
          occurrence: @attributes[:service_occurrence_id], resource: @attributes[:supplier_resource_id]
        )
        ensure_cost_ordinary_edit!(departure, arrangement, version, contractor, charging_supplier)
        ensure_eligible_charging_supplier!(arrangement, version, item, occurrence, charging_supplier)
        attrs = {
          charging_supplier_id: charging_supplier.id,
          label: normalize_text(@attributes[:label], "Label", SupplierCostSource::LABEL_LIMIT),
          notes: normalize_text(@attributes[:notes], "Notes", SupplierCostSource::NOTES_LIMIT, required: false),
          arrangement_item_id: item&.id, service_occurrence_id: occurrence&.id,
          supplier_resource_id: resource&.id
        }
        idempotent_create!(
          command_name: self.class.name, idempotency_key: @idempotency_key,
          payload: attrs.merge(supplier_arrangement_version_id: version.id),
          result_class: SupplierCostSource
        ) do
          ensure_current_lock_version!(version, @version_lock_version)
          siblings = version.supplier_cost_sources.where(arrangement_item_id: item&.id).order(:position, :id).lock.to_a
          source = build_supplier_cost_source_already_locked!(
            version: version,
            arrangement: arrangement,
            attributes: attrs,
            position: siblings.map(&:position).max.to_i + 1
          )
          bump_version!(version)
          audit_cost!("supplier_arrangement.cost_source_created", arrangement, version, {
            "supplier_cost_source_id" => source.id, "charging_supplier_id" => charging_supplier.id,
            "label" => source.label, "position" => source.position
          }.merge(source_context(source)))
          source
        end
      end
    end
  end
end
