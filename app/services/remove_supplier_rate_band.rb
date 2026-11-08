# Removes a band from a custom rate pattern, with its fares (S-14).
class RemoveSupplierRateBand < AgencyCommand
  include SupplierRateCommandSupport

  def initialize(agency:, actor:, departure:, arrangement:, band:)
    @agency = agency
    @actor = actor
    @departure = departure
    @arrangement = arrangement
    @band = band
  end

  def call
    ensure_departure_actor!(:manage_arrangements)

    ActiveRecord::Base.transaction do
      arrangement = lock_draft_arrangement!
      band = arrangement.rate_bands.find(@band.id)
      removed = arrangement.rate_lines.where(supplier_rate_band_id: band.id).delete_all
      band.destroy!
      arrangement.update!(rate_pattern: "custom")
      audit!(agency: @agency, action: "supplier_arrangement.rate_band_removed", subject: arrangement, actor: @actor,
        details: { "supplier_rate_band_id" => band.id, "label" => band.label, "rate_lines_removed" => removed })
      Result.new(status: :removed, record: band)
    end
  end
end
