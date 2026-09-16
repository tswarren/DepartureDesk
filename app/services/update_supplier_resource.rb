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
      arrangement = lock_arrangement_for!(@definition.supplier_arrangement)
      departure = lock_departure_for!(arrangement.departure)
      version = lock_initial_version_for!(arrangement)
      item = lock_arrangement_item_for!(arrangement, @definition.arrangement_item)
      resource = lock_resource_for!(item, @definition.supplier_resource)
      definition = lock_resource_definition_for!(version, @definition)
      ensure_editable_draft_arrangement!(departure, arrangement, version)
      ensure_current_lock_version!(definition)
      return Result.new(status: :noop, record: definition) if same_values?(definition, attrs)

      definition.update!(attrs)
      audit!(
        agency: @agency,
        action: "supplier_arrangement.resource_updated",
        subject: arrangement,
        actor: @actor,
        details: {
          "supplier_arrangement_id" => arrangement.id,
          "supplier_resource_id" => resource.id,
          "supplier_resource_definition_id" => definition.id,
          "changed_fields" => changed_fields(definition, attrs)
        }
      )
      Result.new(status: :updated, record: definition)
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  end
end
