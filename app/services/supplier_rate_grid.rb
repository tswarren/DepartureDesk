# Reads an arrangement's supplier rates as a grid (S-14): a row per
# inventory group, a column per band, and the values that apply to every
# fare. Each cell shows the fare stored for its positions, or what staff
# just typed when a save is refused. Used by the rate page and the
# arrangement's read-only panel.
class SupplierRateGrid
  Cell = Data.define(:key, :group, :band, :positions, :available, :note, :fare, :discount, :overrides) do
    def overridden?(field) = overrides.key?(field)
    def gap? = available && fare.blank?
  end

  DEFAULT_FIELDS = %w[non_commissionable_fees taxes commission_method commission_rate commission_base commission_amount].freeze

  attr_reader :arrangement

  def initialize(arrangement, submitted: nil)
    @arrangement = arrangement
    @submitted = submitted
    @lines = arrangement.rate_lines.to_a.group_by { |line| [ line.inventory_group_id, line.occupancy_position, line.traveler_type_id ] }
  end

  def bands = @bands ||= arrangement.rate_bands.includes(:traveler_type).to_a
  def groups = @groups ||= arrangement.inventory_groups.to_a
  def currency = arrangement.currency
  def pattern = arrangement.rate_pattern

  def self.cell_key(group, band) = "#{group.id}:#{band.id}"

  # The values that apply to every fare, as typed strings.
  def defaults
    @defaults ||= if @submitted
      @submitted.fetch("defaults", {}).to_h.slice(*DEFAULT_FIELDS)
    elsif arrangement.rate_commission_method || arrangement.rate_non_commissionable_fees_minor_units
      stored_defaults
    else
      inferred_defaults
    end
  end

  def cells_for(group) = bands.map { |band| cell(group, band) }

  def cell(group, band)
    key = self.class.cell_key(group, band)
    positions = band.positions_for(group)
    available = positions.any?
    note = available && positions.size < band.positions.size && band.guest_positions.any? ? "#{positions.map { |p| position_label(p) }.join(", ")} only" : nil
    return Cell.new(key:, group:, band:, positions:, available:, note:, fare: nil, discount: nil, overrides: {}) unless available

    if @submitted
      input = @submitted.fetch("cells", {}).to_h.fetch(key, {}).to_h
      overrides = input.fetch("override", {}).to_h.compact_blank
      overrides.delete("commission_method") if overrides["commission_method"] == "inherit"
      return Cell.new(key:, group:, band:, positions:, available:, note:, fare: input["fare"], discount: input["discount"], overrides:)
    end

    line = representative_line(group, band, positions)
    Cell.new(key:, group:, band:, positions:, available:, note:,
      fare: line && display(line.base_fare_minor_units), discount: line && display(line.discount_minor_units), overrides: line ? line_overrides(line) : {})
  end

  def gaps = groups.flat_map { |group| cells_for(group) }.select(&:gap?)

  def position_label(position) = position == "single" ? "single" : "#{position.delete_prefix("guest_").to_i.ordinalize} guest"

  private

  def representative_line(group, band, positions)
    candidates = positions.filter_map { |position| @lines[[ group.id, position, band.traveler_type_id ]]&.first }
    candidates.find { |line| line.supplier_rate_band_id == band.id } || candidates.first
  end

  def line_overrides(line)
    overrides = {}
    overrides["non_commissionable_fees"] = display(line.non_commissionable_fees_minor_units) if line.overridden_fields.include?("non_commissionable_fees")
    overrides["taxes"] = display(line.taxes_minor_units) if line.overridden_fields.include?("taxes")
    if line.overridden_fields.include?("commission")
      overrides.merge!(commission_values(line.commission_rate, line.commission_base, line.commission_minor_units))
    end
    overrides
  end

  def stored_defaults
    {
      "non_commissionable_fees" => display(arrangement.rate_non_commissionable_fees_minor_units),
      "taxes" => display(arrangement.rate_taxes_minor_units)
    }.merge(commission_values(arrangement.rate_commission_rate, arrangement.rate_commission_base, arrangement.rate_commission_minor_units,
      method: arrangement.rate_commission_method))
  end

  # Before any grid save: the most common value on each component, or blanks.
  def inferred_defaults
    lines = @lines.values.flatten
    return { "commission_method" => "percent", "commission_base" => "base_fare" } if lines.empty?

    common = ->(values) { values.tally.max_by(&:last)&.first }
    line = lines.max_by { |candidate| lines.count { |other| other.commission_rate == candidate.commission_rate && other.commission_minor_units == candidate.commission_minor_units } }
    {
      "non_commissionable_fees" => display(common.call(lines.map(&:non_commissionable_fees_minor_units))),
      "taxes" => display(common.call(lines.map(&:taxes_minor_units)))
    }.merge(commission_values(line.commission_rate, line.commission_base, line.commission_minor_units))
  end

  def commission_values(rate, base, amount, method: nil)
    method ||= amount ? "amount" : "percent"
    if method == "amount"
      { "commission_method" => "amount", "commission_amount" => display(amount) }
    else
      { "commission_method" => "percent", "commission_rate" => rate&.to_s("F")&.sub(/\.0\z/, ""), "commission_base" => base || "base_fare" }
    end
  end

  def display(minor_units) = minor_units.nil? ? nil : MoneyInput.display(minor_units, currency).delete(",").delete_suffix(".00")
end
