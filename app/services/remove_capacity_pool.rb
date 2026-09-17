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
      pool.capacity_events.order(:id).lock.load
      pool.capacity_projection&.lock!
      pool.capacity_reconciliations.order(:id).lock.load
      ensure_current_lock_version!(version, @version_lock_version)
      ensure_current_lock_version!(definition)
      carried = pool.definitions.where.not(id: definition.id).exists?
      ensure_draft_pool_can_be_removed!(pool, definition, carried: carried)

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
      pool.destroy! unless carried
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

  def ensure_draft_pool_can_be_removed!(pool, definition, carried:)
    if carried
      dependencies = FindUnresolvedCapacityDependencies.new(
        agency: @agency, arrangement: definition.supplier_arrangement
      ).call
      pending = CapacityEvent.where(id: dependencies.pending_capacity_event_ids, capacity_pool: pool).exists?
      open_reconciliation = CapacityReconciliation.where(
        id: dependencies.open_capacity_reconciliation_ids, capacity_pool: pool
      ).exists?
      nonzero = dependencies.capacity_pool_ids.include?(pool.id)
      return unless pool.numeric_inventory? && (nonzero || pending || open_reconciliation)

      raise Error.new(
        "That carried capacity Pool must have zero effective quantity, no pending event, and clean reconciliation before omission.",
        code: :dependency_exists
      )
    end

    dependencies = [
      pool.capacity_events,
      CapacityProjection.where(capacity_pool: pool),
      pool.capacity_reconciliations
    ]
    return if dependencies.none?(&:exists?)

    raise Error.new("That capacity pool has retained capacity history and cannot be removed from this draft.", code: :invalid_state)
  end
end
