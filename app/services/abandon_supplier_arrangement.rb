class AbandonSupplierArrangement < AgencyCommand
  include ArrangementCommandSupport

  def initialize(agency:, actor:, arrangement:, reason:, arrangement_lock_version:, version_lock_version:)
    @agency = agency
    @actor = actor
    @arrangement = arrangement
    @reason = reason
    @arrangement_lock_version = arrangement_lock_version
    @version_lock_version = version_lock_version
  end

  def call
    ensure_arrangement_actor!

    ActiveRecord::Base.transaction do
      lock_authorized_arrangement_agency!
      arrangement = lock_arrangement_for!(@arrangement)
      departure = lock_departure_for!(arrangement.departure)
      version = lock_initial_version_for!(arrangement)
      return Result.new(status: :noop, record: arrangement) if arrangement.abandoned? && version.abandoned?

      ensure_editable_draft_arrangement!(departure, arrangement, version, allow_departed: true)
      ensure_current_lock_version!(arrangement, @arrangement_lock_version)
      ensure_current_lock_version!(version, @version_lock_version)
      reason = normalize_reason(@reason)
      abandoned_at = Time.current

      arrangement.update!(status: "abandoned", abandoned_at: abandoned_at)
      version.update!(status: "abandoned", abandoned_at: abandoned_at, abandoned_reason: reason)
      audit!(
        agency: @agency,
        action: "supplier_arrangement.abandoned",
        subject: arrangement,
        actor: @actor,
        details: {
          "supplier_arrangement_id" => arrangement.id,
          "supplier_arrangement_version_id" => version.id,
          "reason" => reason
        }
      )
      Result.new(status: :updated, record: arrangement)
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  end
end
