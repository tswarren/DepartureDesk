# One column of an arrangement's supplier rate grid (S-14, SUP-35): a set
# of occupancy positions, for any traveler or for one traveler type. A
# typed band is the exception to an untyped one covering the same
# positions; two bands for the same type never share a position. Frozen
# with the rate table once the arrangement leaves Draft (ADR 0018).
class SupplierRateBand < ApplicationRecord
  LABEL_LIMIT = 60

  belongs_to :agency
  belongs_to :supplier_arrangement, inverse_of: :rate_bands
  belongs_to :traveler_type, optional: true
  has_many :rate_lines, class_name: "SupplierRateLine", foreign_key: :supplier_rate_band_id, inverse_of: :band, dependent: :restrict_with_exception

  attr_readonly :agency_id, :supplier_arrangement_id

  normalizes :label, with: ->(value) { value.to_s.squish }

  validates :label, presence: true, length: { maximum: LABEL_LIMIT }
  validate :positions_known

  scope :ordered, -> { order(:position, :created_at) }

  # The positions of this band a group can hold: single, and each guest up
  # to the group's positions per unit (any guest when the group has none).
  def positions_for(group)
    limit = group.positions_per_unit || SupplierRateLine::MAX_GUEST_POSITION
    positions.select { |position| position == "single" || position.delete_prefix("guest_").to_i <= limit }
  end

  def guest_positions = positions - [ "single" ]

  private

  def positions_known
    if positions.blank?
      errors.add(:positions, "must include at least one")
    elsif (positions - SupplierRateLine::OCCUPANCY_POSITIONS).any?
      errors.add(:positions, "must be single or a guest from the 1st to the 9th")
    end
  end
end
