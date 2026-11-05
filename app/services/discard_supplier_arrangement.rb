# Discards a Draft arrangement: it becomes Cancelled with no supplier or
# financial effect (SUP-11, ADR 0018). Step 3b also waives its open tasks.
class DiscardSupplierArrangement < AgencyCommand
  include ArrangementCommandSupport

  def initialize(agency:, actor:, departure:, arrangement:, lock_version:)
    @agency = agency
    @actor = actor
    @departure = departure
    @arrangement = arrangement
    @lock_version = lock_version
  end

  def call
    ensure_departure_actor!(:manage_arrangements)

    ActiveRecord::Base.transaction do
      departure = lock_arrangement_context!
      arrangement = lock_arrangement!(departure)
      ensure_current_lock_version!(arrangement)
      ensure_draft!(arrangement)

      arrangement.update!(status: "cancelled", cancelled_at: Clock.current.now)
      audit!(
        agency: @agency, action: "supplier_arrangement.discarded", subject: arrangement, actor: @actor,
        details: { "supplier_arrangement_id" => arrangement.id }
      )
      Result.new(status: :updated, record: arrangement)
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  end
end
