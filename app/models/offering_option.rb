# One option in a choice, drawing on one inventory group of its offering's
# Departure (BKG-14, BKG-15). Its client prices are its own (BKG-21).
class OfferingOption < ApplicationRecord
  belongs_to :agency
  belongs_to :choice, class_name: "OfferingChoice", foreign_key: :offering_choice_id, inverse_of: :options
  belongs_to :inventory_group
  has_many :choice_selections, foreign_key: :offering_option_id, dependent: :restrict_with_exception
  has_many :prices, class_name: "OfferingPrice", inverse_of: :option, foreign_key: :offering_option_id, dependent: :restrict_with_exception

  attr_readonly :agency_id, :offering_choice_id

  normalizes :label, with: ->(value) { value.to_s.squish }
  normalizes :description, with: ->(value) { value.to_s.gsub("\r\n", "\n").strip.presence }

  validates :label, presence: true, length: { maximum: Offering::NAME_LIMIT }

  # The positions a traveler can take: each position of a unit for a per-unit
  # choice (the 1st guest when the group has no positions), else any.
  def priced_positions
    return [ "any" ] unless choice.made_per_unit?
    return [ "guest_1" ] if inventory_group.positions_per_unit.nil?

    [ "single", *(1..inventory_group.positions_per_unit).map { |n| "guest_#{n}" } ]
  end

  # The stored positions a band of positions sets on this option: those its
  # group holds. In a group with no stated size the 1st guest has a price
  # and every guest after takes the any-position price.
  def stored_positions_for(positions)
    return positions & [ "any" ] unless choice.made_per_unit?
    return [ "any" ] if positions == [ "any" ]

    if inventory_group.positions_per_unit.nil?
      first = positions & [ "guest_1" ]
      return first if first.any?

      return positions.any? { |position| position.start_with?("guest_") } ? [ "any" ] : []
    end
    positions & priced_positions
  end

  # For an option drawing on one night, such as "Nov 2 Garden Queen" on a
  # group starting Nov 2: the room type after the night, so a range of
  # nights can be chosen together. Nil when the label doesn't start with
  # its group's night.
  def night_kind = inventory_group.night_kind(label)

  # Positions no price row covers for a traveler of no particular type.
  def missing_prices
    lookup = OfferingPriceLookup.new(option: self)
    priced_positions.reject { |position| lookup.price_for(occupancy_position: position == "any" ? nil : position) }
      .map { |position| OfferingPrice::POSITION_LABELS.fetch(position).downcase }
  end
end
