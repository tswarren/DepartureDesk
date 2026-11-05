# One row of an arrangement's supplier rate table (SUP-35): what the
# supplier charges for one occupancy position in one inventory group,
# optionally for one traveler type, as components staff enter. Nothing is
# derived from it until booking confirmation (D-75). Frozen once the
# arrangement leaves Draft (ADR 0018).
class SupplierRateLine < ApplicationRecord
  MAX_GUEST_POSITION = 9
  OCCUPANCY_POSITIONS = [ "single", *(1..MAX_GUEST_POSITION).map { |n| "guest_#{n}" } ].freeze
  AMOUNT_FIELDS = %w[base_fare_minor_units non_commissionable_fees_minor_units taxes_minor_units discount_minor_units commission_minor_units].freeze

  belongs_to :agency
  belongs_to :supplier_arrangement
  belongs_to :inventory_group
  belongs_to :traveler_type, optional: true

  attr_readonly :agency_id, :supplier_arrangement_id, :inventory_group_id, :currency

  validates :occupancy_position, inclusion: { in: OCCUPANCY_POSITIONS }
  validates :currency, format: { with: Agency::CURRENCY_FORMAT }
  validates :base_fare_minor_units, :non_commissionable_fees_minor_units, :taxes_minor_units, :discount_minor_units,
    numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :commission_minor_units, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :commission_rate, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }, allow_nil: true
  validate :commission_rate_or_amount
  validate :position_within_group
  validate :same_arrangement_records

  # Group order, then single before the 1st guest, then traveler type.
  def self.ordered
    joins(:inventory_group).left_joins(:traveler_type)
      .order("inventory_groups.position", "inventory_groups.created_at",
        Arel.sql("CASE WHEN supplier_rate_lines.occupancy_position = 'single' THEN 0 ELSE 1 END"),
        :occupancy_position, Arel.sql("traveler_types.position NULLS FIRST"))
  end

  # 1 to 9, or nil for single occupancy.
  def guest_number
    occupancy_position.delete_prefix("guest_").to_i unless occupancy_position == "single"
  end

  private

  def commission_rate_or_amount
    errors.add(:base, "Enter a commission rate or a commission amount, not both.") if commission_rate && commission_minor_units
  end

  # INV-09: no rate for a guest beyond the unit's maximum occupancy.
  def position_within_group
    return unless inventory_group&.positions_per_unit && guest_number
    return if guest_number <= inventory_group.positions_per_unit

    errors.add(:occupancy_position, "is beyond #{inventory_group.label}'s #{inventory_group.positions_per_unit} positions")
  end

  def same_arrangement_records
    return unless supplier_arrangement

    errors.add(:inventory_group, "must belong to the arrangement") if inventory_group && inventory_group.supplier_arrangement_id != supplier_arrangement_id
    errors.add(:traveler_type, "must belong to the same agency") if traveler_type && traveler_type.agency_id != agency_id
    errors.add(:currency, "must be the arrangement's currency") if currency != supplier_arrangement.currency
  end
end
