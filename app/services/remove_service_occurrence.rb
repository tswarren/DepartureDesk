class RemoveServiceOccurrence < AgencyCommand
  include ArrangementCommandSupport

  def initialize(agency:, actor:, occurrence:, version_lock_version:)
    @agency = agency
    @actor = actor
    @occurrence = occurrence
    @version_lock_version = version_lock_version
  end

  def call
    ensure_arrangement_actor!

    ActiveRecord::Base.transaction do
      lock_authorized_arrangement_agency!
      departure, arrangement, version = lock_departure_arrangement_version!(@occurrence.supplier_arrangement)
      item = lock_arrangement_item_for!(arrangement, @occurrence.arrangement_item)
      occurrence = lock_occurrence_for!(item, @occurrence)
      ensure_cleanup_edit!(departure, arrangement, version)
      ensure_current_lock_version!(version, @version_lock_version)
      ensure_no_capacity_structure_for_occurrence!(version, occurrence)

      definitions = version.service_occurrence_definitions.where(service_occurrence: occurrence).order(:id).lock.to_a
      evidence = {
        "child_type" => "service_occurrence",
        "supplier_arrangement_id" => arrangement.id,
        "supplier_arrangement_version_id" => version.id,
        "arrangement_item_id" => item.id,
        "service_occurrence_id" => occurrence.id,
        "service_occurrence_definition_ids" => definitions.map(&:id)
      }

      definitions.each(&:destroy!)
      occurrence.destroy!
      bump_version!(version)
      audit!(
        agency: @agency,
        action: "supplier_arrangement.occurrence_removed",
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
