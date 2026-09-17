class CreateSupplierResource < AgencyCommand
  include ArrangementCommandSupport

  def initialize(agency:, actor:, item:, attributes:, version_lock_version:, idempotency_key: nil)
    @agency = agency
    @actor = actor
    @item = item
    @attributes = attributes.to_h.with_indifferent_access
    @version_lock_version = version_lock_version
    @idempotency_key = idempotency_key || @attributes.delete(:idempotency_key)
  end

  def call
    ensure_arrangement_actor!
    attrs = normalize_resource_attributes(@attributes)

    ActiveRecord::Base.transaction do
      lock_authorized_arrangement_agency!
      contractor = locked_supplier!(@item.supplier_arrangement.contracting_supplier_id)
      departure, arrangement, version = lock_departure_arrangement_version!(@item.supplier_arrangement)
      item = lock_arrangement_item_for!(arrangement, @item)
      ensure_ordinary_planning_edit!(departure, arrangement, version, contractor)

      idempotent_create!(
        command_name: self.class.name,
        idempotency_key: @idempotency_key,
        payload: attrs.merge(
          supplier_arrangement_id: arrangement.id,
          supplier_arrangement_version_id: version.id,
          arrangement_item_id: item.id
        ),
        result_class: SupplierResource
      ) do
        ensure_current_lock_version!(version, @version_lock_version)
        resource, definition = build_supplier_resource_already_locked!(
          departure: departure,
          arrangement: arrangement,
          version: version,
          item: item,
          attributes: attrs
        )
        bump_version!(version)
        audit!(
          agency: @agency,
          action: "supplier_arrangement.resource_created",
          subject: arrangement,
          actor: @actor,
          details: {
            "child_type" => "supplier_resource",
            "supplier_arrangement_id" => arrangement.id,
            "supplier_arrangement_version_id" => version.id,
            "arrangement_item_id" => item.id,
            "supplier_resource_id" => resource.id,
            "supplier_resource_definition_id" => definition.id,
            "name" => definition.name,
            "position" => definition.position
          }
        )
        resource
      end
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  end
end
