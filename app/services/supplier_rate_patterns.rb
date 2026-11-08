# The preset pricing patterns for a supplier rate grid (S-14): the bands
# each one starts with, sized to the arrangement's largest unit. Custom
# patterns start from the current bands and change one band at a time.
module SupplierRatePatterns
  PATTERNS = %w[cruise_bands per_guest per_room custom].freeze
  LABELS = {
    "cruise_bands" => "Cruise bands", "per_guest" => "One per guest", "per_room" => "Per room", "custom" => "Custom bands"
  }.freeze
  HINTS = {
    "cruise_bands" => "1st and 2nd guest, then the 3rd and more, and single",
    "per_guest" => "A fare for each berth, and single",
    "per_room" => "The 1st guest pays the room; other guests",
    "custom" => "Choose each band's positions and traveler type"
  }.freeze

  module_function

  # [{ label:, positions: }] for a preset, for groups of up to `largest` guests.
  def bands(pattern, largest)
    largest = largest.clamp(1, SupplierRateLine::MAX_GUEST_POSITION)
    guests = ->(range) { range.map { |n| "guest_#{n}" } }
    case pattern
    when "cruise_bands"
      [ { label: "1st and 2nd guest", positions: guests.call(1..[ largest, 2 ].min) },
        (largest >= 3 ? { label: additional_label(largest), positions: guests.call(3..largest) } : nil),
        { label: "Single", positions: [ "single" ] } ].compact
    when "per_guest"
      guests.call(1..largest).map { |position| { label: "#{position.delete_prefix("guest_").to_i.ordinalize} guest", positions: [ position ] } } +
        [ { label: "Single", positions: [ "single" ] } ]
    when "per_room"
      [ { label: "1st guest", positions: [ "single", "guest_1" ] },
        (largest >= 2 ? { label: "Other guests", positions: guests.call(2..largest) } : nil) ].compact
    else
      raise ArgumentError, "#{pattern} has no preset bands"
    end
  end

  def additional_label(largest)
    case largest
    when 3 then "3rd guest"
    when 4 then "3rd and 4th guest"
    else "3rd to #{largest.ordinalize} guest"
    end
  end

  # The largest unit among the arrangement's groups; 4 when none states one.
  def largest_unit(arrangement)
    arrangement.inventory_groups.filter_map(&:positions_per_unit).max || 4
  end
end
