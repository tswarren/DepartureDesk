class RemoveCapacityPairClassification < AgencyCommand
  include CapacityCommandSupport

  def initialize(agency:, actor:, pair:, version_lock_version:, lock_version:)
    @agency = agency
    @actor = actor
    @pair = pair
    @version_lock_version = version_lock_version
    @lock_version = lock_version
  end

  def call
    ensure_arrangement_actor!

    ActiveRecord::Base.transaction do
      lock_authorized_arrangement_agency!
      contractor = locked_supplier!(@pair.supplier_arrangement.contracting_supplier_id)
      departure, arrangement, version = lock_departure_arrangement_version!(@pair.supplier_arrangement)
      ensure_capacity_recovery_edit!(departure, arrangement, version)
      pair = lock_pair_for!(version, @pair)
      ensure_current_lock_version!(version, @version_lock_version)
      ensure_current_lock_version!(pair)
      ensure_pair_has_no_pool_definitions!(pair)

      evidence = {
        "supplier_arrangement_id" => arrangement.id,
        "supplier_arrangement_version_id" => version.id,
        "arrangement_item_id" => pair.arrangement_item_id,
        "capacity_pair_definition_id" => pair.id,
        "service_occurrence_id" => pair.service_occurrence_id,
        "supplier_resource_id" => pair.supplier_resource_id,
        "classification" => pair.classification
      }

      pair.destroy!
      bump_version!(version)
      audit!(
        agency: @agency,
        action: "supplier_arrangement.capacity_pair_removed",
        subject: arrangement,
        actor: @actor,
        details: evidence
      )
      Result.new(status: :updated, record: arrangement)
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  end
end
