# Saves an arrangement's supplier rate grid (S-14, SUP-35): the values that
# apply to every fare, and each group's fare and discount per band, with
# any per-fare overrides of the shared values. Each fare is stored as one
# rate line per position it covers in the group, so the booking cost
# proposal reads the table as before (D-75). A blank fare stores nothing
# for its cell; positions no band covers lose their lines. Draft only
# (ADR 0018); amounts are parsed strictly (ADR 0001).
class SaveSupplierRates < AgencyCommand
  include SupplierRateCommandSupport

  def initialize(agency:, actor:, departure:, arrangement:, defaults:, cells:)
    @agency = agency
    @actor = actor
    @departure = departure
    @arrangement = arrangement
    @defaults = defaults.to_h.stringify_keys.transform_values { |value| value.is_a?(String) ? value.strip : value }
    @cells = cells.to_h.stringify_keys
  end

  def call
    ensure_departure_actor!(:manage_arrangements)

    ActiveRecord::Base.transaction do
      arrangement = lock_draft_arrangement!
      raise Error.new("Choose a pricing pattern first.", code: :invalid_state) if arrangement.rate_bands.empty?

      currency = arrangement.currency
      shared = shared_values(currency)
      arrangement.update!(
        rate_non_commissionable_fees_minor_units: shared[:nccf], rate_taxes_minor_units: shared[:taxes],
        rate_commission_method: shared[:commission][:method], rate_commission_rate: shared[:commission][:rate],
        rate_commission_base: shared[:commission][:base], rate_commission_minor_units: shared[:commission][:amount]
      )
      wanted = wanted_lines(arrangement, shared, currency)
      changes = write_lines!(arrangement, wanted)
      audit!(agency: @agency, action: "supplier_arrangement.rates_saved", subject: arrangement, actor: @actor,
        details: { "rate_lines" => wanted.size }.merge(changes))
      Result.new(status: :updated, record: arrangement)
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  end

  private

  def shared_values(currency)
    {
      nccf: parse_money(@defaults["non_commissionable_fees"], currency, "Non-commissionable fare") || 0,
      taxes: parse_money(@defaults["taxes"], currency, "Taxes and fees") || 0,
      commission: parse_commission(@defaults, currency, "Every fare's")
    }
  end

  # { [group_id, position, type_id] => attributes } for every fare entered.
  def wanted_lines(arrangement, shared, currency)
    arrangement.inventory_groups.each_with_object({}) do |group, wanted|
      arrangement.rate_bands.each do |band|
        positions = band.positions_for(group)
        next if positions.empty?

        input = @cells.fetch(SupplierRateGrid.cell_key(group, band), {}).to_h.stringify_keys
        label = "#{group.label}, #{band.label}"
        fare = parse_money(input["fare"], currency, "#{label}: the fare")
        next if fare.nil?

        attributes = line_attributes(input, shared, currency, label).merge(
          base_fare_minor_units: fare, discount_minor_units: parse_money(input["discount"], currency, "#{label}: the discount") || 0,
          supplier_rate_band_id: band.id
        )
        positions.each { |position| wanted[[ group.id, position, band.traveler_type_id ]] = attributes }
      end
    end
  end

  def line_attributes(input, shared, currency, label)
    override = input.fetch("override", {}).to_h.stringify_keys.transform_values { |value| value.is_a?(String) ? value.strip : value }
    overridden = []
    nccf = parse_money(override["non_commissionable_fees"], currency, "#{label}: the non-commissionable fare")
    overridden << "non_commissionable_fees" if nccf
    taxes = parse_money(override["taxes"], currency, "#{label}: taxes and fees")
    overridden << "taxes" if taxes
    commission = shared[:commission]
    if override["commission_method"].present? && override["commission_method"] != "inherit"
      commission = parse_commission(override, currency, label)
      overridden << "commission"
    end
    {
      non_commissionable_fees_minor_units: nccf || shared[:nccf], taxes_minor_units: taxes || shared[:taxes],
      commission_rate: commission[:rate], commission_base: commission[:base] || "base_fare", commission_minor_units: commission[:amount],
      overridden_fields: overridden
    }
  end

  def write_lines!(arrangement, wanted)
    existing = arrangement.rate_lines.to_a.index_by { |line| [ line.inventory_group_id, line.occupancy_position, line.traveler_type_id ] }
    removed = existing.except(*wanted.keys).values
    SupplierRateLine.where(id: removed.map(&:id)).delete_all
    added = 0
    updated = 0
    wanted.each do |(group_id, position, type_id), attributes|
      line = existing[[ group_id, position, type_id ]]
      if line
        line.assign_attributes(attributes)
        next unless line.changed?

        line.save!
        updated += 1
      else
        arrangement.rate_lines.create!(attributes.merge(agency: @agency, currency: arrangement.currency, inventory_group_id: group_id,
          occupancy_position: position, traveler_type_id: type_id))
        added += 1
      end
    end
    { "added" => added, "updated" => updated, "removed" => removed.size }
  end
end
