# Reads one package choice's client prices as a grid (S-20, BKG-21): a row
# per option and a column per band of occupancy positions, laid out like
# the supplier rate grid when the options' arrangement has one, else the
# 1st guest and other guests. A per-traveler or per-trip choice has one
# price column. A traveler type gets its own column once it has a price or
# staff add one. Each cell reads what a guest at those positions pays now,
# through the price lookup, so a price for any position shows where it
# applies; a typed cell shows only its own price. A column of several
# positions splits into one per guest when staff ask, or by itself once
# its positions hold different prices, so the client side can differ from
# how the supplier bands its fares.
class ClientPriceGrid
  Column = Data.define(:key, :label, :positions, :traveler_type) do
    def splittable? = traveler_type.nil? && positions.size > 1 && positions != [ "any" ]
  end
  Cell = Data.define(:key, :option, :column, :positions, :value, :original, :varies, :inherited, :cost) do
    def available? = positions.any?
  end

  def self.column_key(positions, traveler_type_id) = "#{positions.join("+")}|#{traveler_type_id}"

  attr_reader :choice

  def initialize(choice, extra_type: nil, split: [], submitted: nil, show_cost: false)
    @choice = choice
    @extra_type = extra_type
    @split = Array(split)
    @submitted = submitted
    @show_cost = show_cost
  end

  def currency = choice.offering.currency
  def per_unit? = choice.made_per_unit?
  def show_cost? = @show_cost

  def options
    @options ||= if choice.options.loaded?
      choice.options.to_a
    else
      choice.options.includes({ inventory_group: [ :rate_lines, { supplier_arrangement: { rate_bands: :traveler_type } } ] }, prices: :traveler_type).to_a
    end
  end

  def columns
    @columns ||= begin
      @split_keys = []
      base = per_unit? ? unit_columns : [ Column.new(key: self.class.column_key([ "any" ], nil), label: choice.made_per_traveler? ? "Any traveler" : "Price", positions: [ "any" ], traveler_type: nil) ]
      (base.flat_map { |column| split?(column) ? split(column) : [ column ] } + typed_columns(base)).uniq(&:key)
    end
  end

  def cells_for(option) = columns.map { |column| cell(option, column) }

  # Whether splitting a column would give any option more than one price.
  def splittable?(column) = per_unit? && column.splittable? && options.any? { |option| option.stored_positions_for(column.positions).size > 1 }

  # Keys of the columns shown one per guest, for carrying across a request.
  def split_keys
    columns
    @split_keys
  end

  # Traveler types that could get a column of their own.
  def addable_types
    taken = columns.filter_map { |column| column.traveler_type&.id }
    choice.agency.traveler_types.active.ordered.reject { |type| taken.include?(type.id) }
  end

  def position_label(position)
    case position
    when "single" then "single"
    when "any" then "any position"
    else "#{position.delete_prefix("guest_").to_i.ordinalize} guest"
    end
  end

  private

  def cell(option, column)
    key = "#{option.id}:#{column.key}"
    positions = positions_for(option, column)
    return Cell.new(key:, option:, column:, positions:, value: nil, original: nil, varies: false, inherited: nil, cost: nil) if positions.empty?

    lookup = lookup_for(option)
    amounts = positions.map do |position|
      if column.traveler_type
        option.prices.find { |price| price.occupancy_position == position && price.traveler_type_id == column.traveler_type.id }&.amount_minor_units
      else
        lookup.price_for(occupancy_position: position == "any" ? nil : position)&.amount_minor_units
      end
    end
    varies = amounts.uniq.size > 1
    stored = varies ? nil : display(amounts.first)
    inherited = column.traveler_type && stored.nil? ? untyped_display(lookup, positions) : nil
    value, original = submitted_values(option, column) || [ stored, stored ]
    Cell.new(key:, option:, column:, positions:, value:, original:, varies:, inherited:, cost: cost_for(option.inventory_group, positions, column.traveler_type))
  end

  def split?(column)
    return false unless splittable?(column)

    (@split.include?(column.key) || options.any? { |option| differs?(option, column) }).tap { |split| (@split_keys ||= []) << column.key if split }
  end

  def split(column)
    column.positions.map { |position| Column.new(key: self.class.column_key([ position ], nil), label: position_label(position).upcase_first, positions: [ position ], traveler_type: nil) }
  end

  # Whether an option's guests in a column pay different prices now.
  def differs?(option, column)
    lookup = lookup_for(option)
    option.stored_positions_for(column.positions).map { |position| lookup.price_for(occupancy_position: position == "any" ? nil : position)&.amount_minor_units }.uniq.size > 1
  end

  def lookup_for(option) = (@lookups ||= {})[option.id] ||= OfferingPriceLookup.new(option:)

  # The positions a column covers on one option: those the option's group can hold.
  def positions_for(option, column) = option.stored_positions_for(column.positions)

  def unit_columns
    groups = options.map(&:inventory_group)
    bands = groups.map(&:supplier_arrangement).uniq.flat_map { |arrangement| arrangement.rate_bands.to_a }
    untyped = bands.reject(&:traveler_type_id).uniq(&:positions)
    if untyped.any?
      covered = untyped.flat_map(&:positions)
      if (needed = groups.flat_map { |group| group.positions_per_unit ? [ "single", *(1..group.positions_per_unit).map { |n| "guest_#{n}" } ] : [ "guest_1" ] }.uniq - covered).any?
        untyped += [ Data.define(:label, :positions, :traveler_type_id).new(label: "Other positions", positions: needed, traveler_type_id: nil) ]
      end
      @supplier_typed = bands.select(&:traveler_type_id)
      return untyped.map { |band| Column.new(key: self.class.column_key(band.positions, nil), label: band.label, positions: band.positions, traveler_type: nil) }
    end

    largest = groups.map { |group| group.positions_per_unit || 2 }.max
    SupplierRatePatterns.bands("per_room", largest).map do |band|
      Column.new(key: self.class.column_key(band[:positions], nil), label: band[:label], positions: band[:positions], traveler_type: nil)
    end
  end

  # A column for each traveler type with a supplier band, a price, or just added.
  def typed_columns(base)
    columns = Array(@supplier_typed).map do |band|
      Column.new(key: self.class.column_key(band.positions, band.traveler_type_id), label: "#{band.label}, #{band.traveler_type.name}", positions: band.positions, traveler_type: band.traveler_type)
    end
    options.flat_map(&:prices).select(&:traveler_type_id).group_by(&:traveler_type).sort_by { |type, _| type.position.to_i }.each do |type, prices|
      next if columns.any? { |column| column.traveler_type == type }

      positions = prices.map(&:occupancy_position).uniq.sort_by { |position| OfferingPrice::POSITIONS.index(position) }
      columns << typed_column(base, positions, type)
    end
    if @extra_type && columns.none? { |column| column.traveler_type == @extra_type }
      positions = per_unit? ? added_type_positions(base) : [ "any" ]
      columns << typed_column(base, positions, @extra_type)
    end
    columns
  end

  # A new traveler-type column starts on the guests after the 1st, where
  # types usually differ, or the 1st guest when a unit holds one.
  def added_type_positions(base)
    later = base.reverse.find { |column| column.positions.any? { |position| position.start_with?("guest_") && position != "guest_1" } }
    (later || base.first).positions
  end

  def typed_column(base, positions, type)
    return Column.new(key: self.class.column_key(positions, type.id), label: type.name, positions:, traveler_type: type) if positions == [ "any" ]

    named = base.find { |column| column.positions == positions }&.label
    label = named || positions.map { |position| position_label(position) }.to_sentence.upcase_first
    Column.new(key: self.class.column_key(positions, type.id), label: "#{label}, #{type.name}", positions:, traveler_type: type)
  end

  def untyped_display(lookup, positions)
    amounts = positions.map { |position| lookup.price_for(occupancy_position: position == "any" ? nil : position)&.amount_minor_units }
    amounts.uniq.size == 1 && amounts.first ? money(amounts.first) : nil
  end

  def submitted_values(option, column)
    return nil unless @submitted

    [ @submitted.dig("prices", option.id, column.key), @submitted.dig("original", option.id, column.key) ]
  end

  # The net supplier cost per guest for these positions, or a range.
  def cost_for(group, positions, traveler_type)
    return nil unless @show_cost

    rates = group.rate_lines.to_a
    nets = positions.flat_map do |position|
      candidates = position == "any" ? rates : rates.select { |line| line.occupancy_position == position }
      typed = traveler_type && candidates.select { |line| line.traveler_type_id == traveler_type.id }
      (typed.presence || candidates.reject(&:traveler_type_id)).map { |line| ProposeBookingSupplierCost.net_for(line) }
    end.uniq.sort
    return nil if nets.empty?

    nets.one? ? money(nets.first) : "#{money(nets.first)} to #{money(nets.last)}"
  end

  public

  # A cell's price as the package page shows it.
  def shown(cell)
    return nil unless cell.available?
    return "Varies" if cell.varies
    return "Same as any" if cell.value.blank? && cell.column.traveler_type
    return "Not set" if cell.value.blank?

    money(MoneyInput.minor_units(cell.value, currency))
  end

  private

  def money(minor_units) = Money.new(minor_units, currency).format(no_cents_if_whole: true)
  def display(minor_units) = minor_units.nil? ? nil : MoneyInput.display(minor_units, currency).delete(",").delete_suffix(".00")
end
