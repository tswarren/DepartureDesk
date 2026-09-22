class UpdateSupplierResource < AgencyCommand
  include ArrangementCommandSupport

  def initialize(agency:, actor:, definition:, attributes:, lock_version:)
    @agency = agency
    @actor = actor
    @definition = definition
    @attributes = attributes.to_h.with_indifferent_access
    @lock_version = lock_version
  end

  def call
    ensure_arrangement_actor!
    attrs = normalize_resource_attributes(@attributes)

    ActiveRecord::Base.transaction do
      lock_authorized_arrangement_agency!
      contractor = locked_supplier!(@definition.supplier_arrangement.contracting_supplier_id)
      departure, arrangement, version = lock_departure_arrangement_version!(@definition.supplier_arrangement)
      item = lock_arrangement_item_for!(arrangement, @definition.arrangement_item)
      resource = lock_resource_for!(item, @definition.supplier_resource)
      definition = lock_resource_definition_for!(version, @definition)
      ensure_ordinary_planning_edit!(departure, arrangement, version, contractor)
      ensure_current_lock_version!(definition)
      submitted = @attributes.to_h.with_indifferent_access
      attrs[:supplier_code] = definition.supplier_code unless submitted.key?(:supplier_code)
      attrs[:maximum_occupancy] = definition.maximum_occupancy unless submitted.key?(:maximum_occupancy)
      return Result.new(status: :noop, record: definition) if same_values?(definition, attrs)

      definition.update!(attrs)
      audit!(
        agency: @agency,
        action: "supplier_arrangement.resource_updated",
        subject: arrangement,
        actor: @actor,
        details: {
          "child_type" => "supplier_resource",
          "supplier_arrangement_id" => arrangement.id,
          "supplier_arrangement_version_id" => version.id,
          "arrangement_item_id" => item.id,
          "supplier_resource_id" => resource.id,
          "supplier_resource_definition_id" => definition.id,
          "changed_fields" => changed_fields(definition, attrs),
          "position" => definition.position
        }
      )
      Result.new(status: :updated, record: definition)
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  end
end
