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
      arrangement = lock_arrangement_for!(@occurrence.supplier_arrangement)
      departure = lock_departure_for!(arrangement.departure)
      version = lock_initial_version_for!(arrangement)
      item = lock_arrangement_item_for!(arrangement, @occurrence.arrangement_item)
      occurrence = lock_occurrence_for!(item, @occurrence)
      ensure_editable_draft_arrangement!(departure, arrangement, version, allow_departed: true)
      ensure_current_lock_version!(version, @version_lock_version)

      version.service_occurrence_definitions.where(service_occurrence: occurrence).order(:id).lock.each(&:destroy!)
      occurrence.destroy!
      bump_version!(version)
      audit!(
        agency: @agency,
        action: "supplier_arrangement.occurrence_removed",
        subject: arrangement,
        actor: @actor,
        details: { "supplier_arrangement_id" => arrangement.id, "service_occurrence_id" => occurrence.id }
      )
      Result.new(status: :updated, record: arrangement)
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  end
end
