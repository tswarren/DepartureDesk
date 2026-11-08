# Starts or changes an arrangement's rate grid from a pattern (S-14). A
# preset replaces the bands with its own; the stored fares stay on their
# positions, so a cruise-band fare shows under each guest it covered.
# Custom keeps the current bands, or starts from cruise bands, to edit.
class SetSupplierRatePattern < AgencyCommand
  include SupplierRateCommandSupport

  def initialize(agency:, actor:, departure:, arrangement:, pattern:)
    @agency = agency
    @actor = actor
    @departure = departure
    @arrangement = arrangement
    @pattern = pattern.to_s
  end

  def call
    ensure_departure_actor!(:manage_arrangements)
    raise Error.new("Choose a pattern.", code: :invalid) unless @pattern.in?(SupplierRatePatterns::PATTERNS)

    ActiveRecord::Base.transaction do
      arrangement = lock_draft_arrangement!
      if @pattern == "custom"
        replace_bands!(arrangement, SupplierRatePatterns.bands("cruise_bands", SupplierRatePatterns.largest_unit(arrangement))) if arrangement.rate_bands.empty?
      else
        replace_bands!(arrangement, SupplierRatePatterns.bands(@pattern, SupplierRatePatterns.largest_unit(arrangement)))
      end
      arrangement.update!(rate_pattern: @pattern)
      audit!(agency: @agency, action: "supplier_arrangement.rate_pattern_set", subject: arrangement, actor: @actor,
        details: { "rate_pattern" => @pattern, "bands" => arrangement.rate_bands.map(&:label) })
      Result.new(status: :updated, record: arrangement)
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  end
end
