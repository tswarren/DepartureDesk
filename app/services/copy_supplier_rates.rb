# Copies another arrangement's rate grid onto a draft one (S-14): its
# pattern, bands, shared values and fares, matching inventory groups by
# label. The source must be the same supplier in the same currency. It
# replaces the draft's own rates; staff then check them against the
# supplier's current rate sheet.
class CopySupplierRates < AgencyCommand
  include SupplierRateCommandSupport

  def initialize(agency:, actor:, departure:, arrangement:, source_id:)
    @agency = agency
    @actor = actor
    @departure = departure
    @arrangement = arrangement
    @source_id = source_id
  end

  def call
    ensure_departure_actor!(:manage_arrangements)

    ActiveRecord::Base.transaction do
      arrangement = lock_draft_arrangement!
      source = self.class.sources(@agency, arrangement).find_by(id: parse_optional_uuid(@source_id, "Arrangement"))
      raise Error.new("Choose an arrangement with the same supplier and currency.", code: :invalid) if source.nil?

      copy_shared!(arrangement, source)
      bands = copy_bands!(arrangement, source)
      copied, skipped = copy_lines!(arrangement, source, bands)
      audit!(agency: @agency, action: "supplier_arrangement.rates_copied", subject: arrangement, actor: @actor,
        details: { "source_arrangement_id" => source.id, "rate_lines_copied" => copied, "rate_lines_skipped" => skipped })
      Result.new(status: :updated, record: { source:, copied:, skipped: })
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  end

  # Arrangements of the same supplier and currency, other than this one, with rates.
  def self.sources(agency, arrangement)
    agency.supplier_arrangements.where(supplier_id: arrangement.supplier_id, currency: arrangement.currency)
      .where.not(id: arrangement.id).where(id: SupplierRateLine.select(:supplier_arrangement_id))
  end

  private

  def copy_shared!(arrangement, source)
    arrangement.update!(source.attributes.slice(*%w[
      rate_pattern rate_non_commissionable_fees_minor_units rate_taxes_minor_units rate_commission_method
      rate_commission_rate rate_commission_base rate_commission_minor_units
    ]).merge("rate_pattern" => source.rate_pattern || "custom"))
  end

  def copy_bands!(arrangement, source)
    definitions = source.rate_bands.map { |band| { label: band.label, positions: band.positions, traveler_type_id: band.traveler_type_id } }
    replace_bands!(arrangement, definitions)
    source.rate_bands.zip(arrangement.rate_bands.reload).to_h { |from, to| [ from.id, to.id ] }
  end

  def copy_lines!(arrangement, source, bands)
    groups = arrangement.inventory_groups.index_by(&:label)
    SupplierRateLine.where(supplier_arrangement_id: arrangement.id).delete_all
    copied = 0
    skipped = 0
    source.rate_lines.includes(:inventory_group).each do |line|
      group = groups[line.inventory_group.label]
      limit = group&.positions_per_unit || SupplierRateLine::MAX_GUEST_POSITION
      if group.nil? || (line.guest_number && line.guest_number > limit)
        skipped += 1
        next
      end

      arrangement.rate_lines.create!(line.attributes.slice(*%w[
        occupancy_position traveler_type_id base_fare_minor_units non_commissionable_fees_minor_units taxes_minor_units
        discount_minor_units commission_rate commission_base commission_minor_units overridden_fields
      ]).merge(agency: @agency, currency: arrangement.currency, inventory_group: group, supplier_rate_band_id: bands[line.supplier_rate_band_id]))
      copied += 1
    end
    [ copied, skipped ]
  end
end
