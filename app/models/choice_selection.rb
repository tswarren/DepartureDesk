# One option chosen on a booking (BKG-14, BKG-16). A per-unit selection is
# one unit, such as cabin 1, whose occupants have positions in that unit; a
# per-traveler selection lists its participants; a per-trip selection has
# neither (step 6 plan, question 19).
class ChoiceSelection < ApplicationRecord
  belongs_to :agency
  belongs_to :client_booking, inverse_of: :choice_selections
  belongs_to :option, class_name: "OfferingOption", foreign_key: :offering_option_id
  has_many :occupants, -> { order(Arel.sql("position NULLS LAST"), :created_at) }, class_name: "SelectionOccupant", inverse_of: :choice_selection, dependent: :restrict_with_exception
  has_many :inventory_allocations, dependent: :restrict_with_exception
  has_many :price_lines, class_name: "BookingPriceLine", dependent: :restrict_with_exception
  has_many :supplier_reservation_units, dependent: :restrict_with_exception

  attr_readonly :agency_id, :client_booking_id

  delegate :choice, to: :option
  delegate :inventory_group, to: :option

  def per_unit? = choice.made_per_unit?
  def per_traveler? = choice.made_per_traveler?

  # Step 7 plan, question 3: on-request, rate-only and directly booked
  # space, and anything under a per-unit arrangement, needs its own supplier
  # request; block space under arrangement scope is covered by the
  # arrangement's confirmation. An arrangement that tracks none needs none.
  def needs_supplier_request?
    group = inventory_group
    arrangement = group.supplier_arrangement
    return false if arrangement.reservations_none?

    arrangement.reservations_per_unit? || group.represented_as_none? || group.availability_promise.in?(InventoryGroup::NON_NUMERIC_PROMISES)
  end

  # The open supplier reservation covering this unit, if any.
  def open_supplier_reservation
    supplier_reservation_units.select(&:open).map(&:supplier_reservation).first
  end

  def label
    per_unit? ? "#{choice.name} #{unit_number}: #{option.label}" : option.label
  end
end
