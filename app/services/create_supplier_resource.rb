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
      arrangement = lock_arrangement_for!(@item.supplier_arrangement)
      departure = lock_departure_for!(arrangement.departure)
      version = lock_initial_version_for!(arrangement)
      item = lock_arrangement_item_for!(arrangement, @item)
      ensure_editable_draft_arrangement!(departure, arrangement, version)
      ensure_current_lock_version!(version, @version_lock_version)

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
        resource = item.supplier_resources.create!(
          agency: @agency,
          departure: departure,
          supplier_arrangement: arrangement
        )
        version.supplier_resource_definitions.create!(
          attrs.merge(
            agency: @agency,
            departure: departure,
            supplier_arrangement: arrangement,
            arrangement_item: item,
            supplier_resource: resource,
            position: next_resource_position(version, item)
          )
        )
        bump_version!(version)
        audit!(
          agency: @agency,
          action: "supplier_arrangement.resource_created",
          subject: arrangement,
          actor: @actor,
          details: { "supplier_arrangement_id" => arrangement.id, "supplier_resource_id" => resource.id }
        )
        resource
      end
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  end
end
