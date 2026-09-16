class UpdateCapacityPool < AgencyCommand
  include CapacityCommandSupport

  def initialize(agency:, actor:, definition:, attributes:, lock_version:)
    @agency = agency
    @actor = actor
    @definition = definition
    @attributes = attributes.to_h.with_indifferent_access
    @lock_version = lock_version
  end

  def call
    ensure_arrangement_actor!

    ActiveRecord::Base.transaction do
      lock_authorized_arrangement_agency!
      contractor = locked_supplier!(@definition.supplier_arrangement.contracting_supplier_id)
      departure, arrangement, version = lock_departure_arrangement_version!(@definition.supplier_arrangement)
      ensure_capacity_ordinary_edit!(departure, arrangement, version, contractor)
      definition = lock_pool_definition_for!(version, @definition)
      pool = lock_pool_for!(arrangement, definition.capacity_pool)
      attrs = normalize_pool_definition_update_attributes(@attributes, definition)
      ensure_current_lock_version!(definition)

      return Result.new(status: :noop, record: definition) if same_values?(definition, attrs)

      definition.update!(attrs)
      audit!(
        agency: @agency,
        action: "supplier_arrangement.capacity_pool_updated",
        subject: arrangement,
        actor: @actor,
        details: {
          "supplier_arrangement_id" => arrangement.id,
          "supplier_arrangement_version_id" => version.id,
          "arrangement_item_id" => definition.arrangement_item_id,
          "capacity_pair_definition_id" => definition.capacity_pair_definition_id,
          "capacity_pool_id" => pool.id,
          "capacity_pool_definition_id" => definition.id,
          "supplying_supplier_id" => pool.supplying_supplier_id,
          "inventory_mode" => pool.inventory_mode,
          "measurement_basis" => pool.measurement_basis,
          "changed_fields" => capacity_definition_changed_fields(definition, attrs),
          "label" => definition.label,
          "unit_label" => definition.unit_label,
          "proposed_opening_quantity" => definition.proposed_opening_quantity,
          "evidence_kind" => definition.evidence_kind,
          "override" => definition.override?
        }
      )
      Result.new(status: :updated, record: definition)
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  end
end
