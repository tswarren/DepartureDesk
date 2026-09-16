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
      arrangement = lock_arrangement_for!(@item.supplier_arrangement)
      departure = lock_departure_for!(arrangement.departure)
      version = lock_initial_version_for!(arrangement)
      item = lock_arrangement_item_for!(arrangement, @item)
      ensure_editable_draft_arrangement!(departure, arrangement, version, allow_departed: true)
      ensure_current_lock_version!(version, @version_lock_version)

      version.service_occurrence_definitions.where(arrangement_item: item).order(:id).lock.each(&:destroy!)
      item.service_occurrences.order(:id).lock.each(&:destroy!)
      version.supplier_resource_definitions.where(arrangement_item: item).order(:position, :id).lock.each(&:destroy!)
      item.supplier_resources.order(:id).lock.each(&:destroy!)
      version.arrangement_item_definitions.where(arrangement_item: item).order(:id).lock.each(&:destroy!)
      item.destroy!
      bump_version!(version)
      audit!(
        agency: @agency,
        action: "supplier_arrangement.item_removed",
        subject: arrangement,
        actor: @actor,
        details: { "supplier_arrangement_id" => arrangement.id, "arrangement_item_id" => item.id }
      )
      Result.new(status: :updated, record: arrangement)
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  end
end
