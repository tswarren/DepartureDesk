class RemoveSupplierResource < AgencyCommand
  include ArrangementCommandSupport

  def initialize(agency:, actor:, resource:, version_lock_version:)
    @agency = agency
    @actor = actor
    @resource = resource
    @version_lock_version = version_lock_version
  end

  def call
    ensure_arrangement_actor!

    ActiveRecord::Base.transaction do
      lock_authorized_arrangement_agency!
      departure, arrangement, version = lock_departure_arrangement_version!(@resource.supplier_arrangement)
      item = lock_arrangement_item_for!(arrangement, @resource.arrangement_item)
      resource = lock_resource_for!(item, @resource)
      ensure_cleanup_edit!(departure, arrangement, version)
      ensure_current_lock_version!(version, @version_lock_version)
      ensure_no_capacity_structure_for_resource!(version, resource)
      ensure_no_cost_structure_for_resource!(version, resource)

      definitions = version.supplier_resource_definitions.where(supplier_resource: resource).order(:id).lock.to_a
      evidence = {
        "child_type" => "supplier_resource",
        "supplier_arrangement_id" => arrangement.id,
        "supplier_arrangement_version_id" => version.id,
        "arrangement_item_id" => item.id,
        "supplier_resource_id" => resource.id,
        "supplier_resource_definition_ids" => definitions.map(&:id)
      }

      definitions.each(&:destroy!)
      resource.destroy!
      bump_version!(version)
      audit!(
        agency: @agency,
        action: "supplier_arrangement.resource_removed",
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
