class RemoveCapacityPool < AgencyCommand
  include CapacityCommandSupport

  def initialize(agency:, actor:, definition:, version_lock_version:, lock_version:)
    @agency = agency
    @actor = actor
    @definition = definition
    @version_lock_version = version_lock_version
    @lock_version = lock_version
  end

  def call
    ensure_arrangement_actor!

    ActiveRecord::Base.transaction do
      lock_authorized_arrangement_agency!
      contractor = locked_supplier!(@definition.supplier_arrangement.contracting_supplier_id)
      departure, arrangement, version = lock_departure_arrangement_version!(@definition.supplier_arrangement)
      ensure_capacity_recovery_edit!(departure, arrangement, version)
      definition = lock_pool_definition_for!(version, @definition)
      pool = lock_pool_for!(arrangement, definition.capacity_pool)
      ensure_current_lock_version!(version, @version_lock_version)
      ensure_current_lock_version!(definition)
      ensure_draft_pool_can_be_destroyed!(pool, definition)

      evidence = {
        "supplier_arrangement_id" => arrangement.id,
        "supplier_arrangement_version_id" => version.id,
        "arrangement_item_id" => definition.arrangement_item_id,
        "capacity_pair_definition_id" => definition.capacity_pair_definition_id,
        "capacity_pool_id" => pool.id,
        "capacity_pool_definition_id" => definition.id,
        "service_occurrence_id" => definition.service_occurrence_id,
        "supplier_resource_id" => definition.supplier_resource_id,
        "supplying_supplier_id" => pool.supplying_supplier_id,
        "inventory_mode" => pool.inventory_mode,
        "measurement_basis" => pool.measurement_basis,
        "position" => definition.position
      }

      definition.destroy!
      pool.destroy!
      bump_version!(version)
      audit!(
        agency: @agency,
        action: "supplier_arrangement.capacity_pool_removed",
        subject: arrangement,
        actor: @actor,
        details: evidence
      )
      Result.new(status: :updated, record: arrangement)
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  end

  private

  def ensure_draft_pool_can_be_destroyed!(pool, definition)
    dependencies = [
      pool.definitions.where.not(id: definition.id),
      pool.capacity_events,
      CapacityProjection.where(capacity_pool: pool),
      pool.capacity_reconciliations
    ]
    return if dependencies.none?(&:exists?)

    raise Error.new("That capacity pool has retained capacity history and cannot be removed from this draft.", code: :invalid_state)
  end
end
