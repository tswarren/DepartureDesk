# Edits a Draft arrangement in place (ADR 0018). After Confirm, changes are
# dated adjustments, which later steps add.
class UpdateSupplierArrangement < AgencyCommand
  include ArrangementCommandSupport

  def initialize(agency:, actor:, departure:, arrangement:, attributes:, lock_version:)
    @agency = agency
    @actor = actor
    @departure = departure
    @arrangement = arrangement
    @attributes = attributes.to_h.stringify_keys
    @lock_version = lock_version
  end

  def call
    ensure_departure_actor!(:manage_arrangements)

    ActiveRecord::Base.transaction do
      departure = lock_arrangement_context!
      arrangement = lock_arrangement!(departure)
      ensure_current_lock_version!(arrangement)
      ensure_draft!(arrangement)

      arrangement.assign_attributes(arrangement_attributes(arrangement.supplier))
      changed = arrangement.changed - %w[lock_version updated_at]
      return Result.new(status: :noop, record: arrangement) if changed.empty?

      arrangement.save!
      audit!(
        agency: @agency, action: "supplier_arrangement.updated", subject: arrangement, actor: @actor,
        details: { "supplier_arrangement_id" => arrangement.id, "changed" => changed.sort }
      )
      Result.new(status: :updated, record: arrangement)
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  end
end
