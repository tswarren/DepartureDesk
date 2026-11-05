# The smallest part of an arrangement with its own availability and
# allocation rules (INV-01). It uses one representation (INV-03) and has an
# availability promise defaulting from its arrangement (SUP-15).
class InventoryGroup < ApplicationRecord
  SERVICE_CATEGORIES = %w[hotel all_inclusive_resort cruise air rail transportation activity meal insurance].freeze
  REPRESENTATIONS = %w[unit_shells capacity_pool none].freeze
  # INV-12's suggested representation for each service category.
  DEFAULT_REPRESENTATIONS = {
    "hotel" => "unit_shells", "all_inclusive_resort" => "unit_shells", "cruise" => "unit_shells",
    "air" => "capacity_pool", "rail" => "capacity_pool", "transportation" => "unit_shells",
    "activity" => "capacity_pool", "meal" => "capacity_pool", "insurance" => "none"
  }.freeze
  NON_NUMERIC_PROMISES = %w[on_request rate_only].freeze
  LABEL_LIMIT = 120

  belongs_to :agency
  belongs_to :supplier_arrangement
  has_many :capacity_rules, dependent: :restrict_with_exception
  has_many :unit_shells, -> { ordered }, inverse_of: :inventory_group, dependent: :restrict_with_exception
  has_one :capacity_pool, dependent: :restrict_with_exception
  has_many :capacity_events, dependent: :restrict_with_exception
  has_one :capacity_projection, dependent: :restrict_with_exception
  has_many :rate_lines, class_name: "SupplierRateLine", dependent: :restrict_with_exception

  enum :service_category, SERVICE_CATEGORIES.index_by(&:itself), validate: true, prefix: :category
  enum :representation, REPRESENTATIONS.index_by(&:itself), validate: true, prefix: :represented_as
  enum :availability_promise, SupplierArrangement::AVAILABILITY_PROMISES.index_by(&:itself), validate: true, prefix: :promise

  attr_readonly :agency_id, :supplier_arrangement_id

  normalizes :label, with: ->(value) { value.to_s.squish }
  normalizes :time_zone, with: ->(value) { value.to_s.strip.presence }

  validates :label, presence: true, length: { maximum: LABEL_LIMIT }
  validates :quantity, numericality: { only_integer: true, greater_than_or_equal_to: 1 }, allow_nil: true
  validates :positions_per_unit, numericality: { only_integer: true, greater_than_or_equal_to: 1 }, allow_nil: true
  validate :quantity_only_when_numeric
  validate :positions_only_for_shells
  validate :dates_paired_and_ordered
  validate :time_zone_is_iana

  scope :ordered, -> { order(:position, :created_at) }

  # INV-04: On request, Rate only and no shared inventory show no balance.
  def numeric?
    !represented_as_none? && !availability_promise.in?(NON_NUMERIC_PROMISES)
  end

  # What Confirm needs from this group.
  def confirmation_blockers
    blockers = []
    blockers << "Enter service dates for #{label}." if starts_on.blank? || time_zone.blank?
    blockers << "Enter how many units or places #{label} has." if numeric? && quantity.blank?
    blockers << "Enter the positions per unit for #{label}." if represented_as_unit_shells? && numeric? && positions_per_unit.blank?
    blockers
  end

  private

  def quantity_only_when_numeric
    errors.add(:quantity, "must be blank for #{availability_promise.humanize.downcase} or no shared inventory") if quantity.present? && !numeric?
  end

  def positions_only_for_shells
    errors.add(:positions_per_unit, "applies only to unit shells") if positions_per_unit.present? && !represented_as_unit_shells?
  end

  def dates_paired_and_ordered
    errors.add(:base, "Enter both a start date and an end date, or neither.") if starts_on.blank? ^ ends_on.blank?
    errors.add(:ends_on, "must be on or after the start date") if starts_on && ends_on && ends_on < starts_on
  end

  def time_zone_is_iana
    return if time_zone.blank?

    TZInfo::Timezone.get(time_zone)
  rescue TZInfo::InvalidTimezoneIdentifier
    errors.add(:time_zone, "is not a recognized IANA timezone")
  end
end
