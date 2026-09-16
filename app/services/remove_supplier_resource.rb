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
      arrangement = lock_arrangement_for!(@resource.supplier_arrangement)
      departure = lock_departure_for!(arrangement.departure)
      version = lock_initial_version_for!(arrangement)
      item = lock_arrangement_item_for!(arrangement, @resource.arrangement_item)
      resource = lock_resource_for!(item, @resource)
      ensure_editable_draft_arrangement!(departure, arrangement, version, allow_departed: true)
      ensure_current_lock_version!(version, @version_lock_version)

      version.supplier_resource_definitions.where(supplier_resource: resource).order(:id).lock.each(&:destroy!)
      resource.destroy!
      bump_version!(version)
      audit!(
        agency: @agency,
        action: "supplier_arrangement.resource_removed",
        subject: arrangement,
        actor: @actor,
        details: { "supplier_arrangement_id" => arrangement.id, "supplier_resource_id" => resource.id }
      )
      Result.new(status: :updated, record: arrangement)
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  end
end
