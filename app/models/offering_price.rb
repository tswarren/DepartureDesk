# A client price on an offering option (BKG-21): for one occupancy position
# (or any position) and optionally one traveler type, in the offering's
# currency. Changing it never changes a booking (BKG-23).
class OfferingPrice < ApplicationRecord
  POSITIONS = [ "any", "single", *(1..9).map { |n| "guest_#{n}" } ].freeze
  POSITION_LABELS = {
    "any" => "Any position", "single" => "Single occupancy", **(1..9).to_h { |n| [ "guest_#{n}", "#{n.ordinalize} guest" ] }
  }.freeze

  belongs_to :agency
  belongs_to :option, class_name: "OfferingOption", foreign_key: :offering_option_id, inverse_of: :prices
  belongs_to :traveler_type, optional: true

  attr_readonly :agency_id, :offering_option_id, :currency

  validates :occupancy_position, inclusion: { in: POSITIONS }
  validates :amount_minor_units, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :currency, format: { with: Agency::CURRENCY_FORMAT }
  validate :position_within_group

  # Specific positions first, any position last.
  def sort_key = [ occupancy_position == "any" ? POSITIONS.size : POSITIONS.index(occupancy_position), traveler_type&.position.to_i ]

  def guest_number = occupancy_position.start_with?("guest_") ? occupancy_position.delete_prefix("guest_").to_i : nil

  private

  # INV-09: no price for a guest beyond the unit's maximum occupancy.
  def position_within_group
    limit = option&.inventory_group&.positions_per_unit
    return unless limit && guest_number && guest_number > limit

    errors.add(:occupancy_position, "is beyond #{option.inventory_group.label}'s #{limit} positions")
  end
end
