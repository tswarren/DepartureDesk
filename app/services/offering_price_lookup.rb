# The client price for one traveler on an offering option (BKG-21). It
# tries the traveler's occupancy position first, then, for a guest alone in
# a unit, the 1st-guest price, then the any-position price; at each, a row
# for the traveler's type before the row for any type. A per-traveler or
# per-trip option is looked up with no position. Step 6 proposes booking
# prices from it; nothing here posts a price.
class OfferingPriceLookup
  def initialize(option:)
    @option = option
    @prices = option.prices.to_a
  end

  def price_for(occupancy_position:, traveler_type: nil)
    positions = [ occupancy_position, ("guest_1" if occupancy_position == "single"), "any" ].compact.uniq
    positions.each do |position|
      rows = @prices.select { |price| price.occupancy_position == position }
      found = rows.find { |price| traveler_type && price.traveler_type_id == traveler_type.id } || rows.find { |price| price.traveler_type_id.nil? }
      return found if found
    end
    nil
  end
end
