class RemoveArrangementItem < AgencyCommand
  include ArrangementCommandSupport

  def initialize(agency:, actor:, item:, version_lock_version:)
    @agency = agency
    @actor = actor
    @item = item
    @version_lock_version = version_lock_version
  end

  def call
    ensure_arrangement_actor!

    ActiveRecord::Base.transaction do
      lock_authorized_arrangement_agency!
      departure, arrangement, version = lock_departure_arrangement_version!(@item.supplier_arrangement)
      item = lock_arrangement_item_for!(arrangement, @item)
      ensure_cleanup_edit!(departure, arrangement, version)
      ensure_current_lock_version!(version, @version_lock_version)
      ensure_no_capacity_structure_for_item!(version, item)
      ensure_no_cost_structure_for_item!(version, item)

      occurrence_definitions = version.service_occurrence_definitions.where(arrangement_item: item).order(:id).lock.to_a
      occurrences = item.service_occurrences.order(:id).lock.to_a
      resource_definitions = version.supplier_resource_definitions.where(arrangement_item: item).order(:position, :id).lock.to_a
      resources = item.supplier_resources.order(:id).lock.to_a
      item_definitions = version.arrangement_item_definitions.where(arrangement_item: item).order(:id).lock.to_a

      evidence = {
        "child_type" => "arrangement_item",
        "supplier_arrangement_id" => arrangement.id,
        "supplier_arrangement_version_id" => version.id,
        "arrangement_item_id" => item.id,
        "arrangement_item_definition_ids" => item_definitions.map(&:id),
        "service_occurrence_ids" => occurrences.map(&:id),
        "service_occurrence_definition_ids" => occurrence_definitions.map(&:id),
        "supplier_resource_ids" => resources.map(&:id),
        "supplier_resource_definition_ids" => resource_definitions.map(&:id)
      }

      occurrence_definitions.each(&:destroy!)
      occurrences.each(&:destroy!)
      resource_definitions.each(&:destroy!)
      resources.each(&:destroy!)
      item_definitions.each(&:destroy!)
      item.destroy!
      bump_version!(version)
      audit!(
        agency: @agency,
        action: "supplier_arrangement.item_removed",
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
