# A client cancellation tier (BKG-31): from a number of days before
# departure, a percentage of the affected service's accepted client
# charge, or a fixed amount per traveler or per unit of a named service
# category. Shared by the agency's defaults and a Departure's override.
module CancellationTier
  extend ActiveSupport::Concern

  CHARGE_KINDS = %w[percentage fixed_per_traveler fixed_per_unit].freeze

  included do
    enum :charge_kind, CHARGE_KINDS.index_by(&:itself), validate: true

    validates :min_days_before_departure, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
    validates :percentage, numericality: { greater_than: 0, less_than_or_equal_to: 100 }, if: :percentage?
    validates :amount_minor_units, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, unless: :percentage?
    validates :service_category, inclusion: { in: InventoryGroup::SERVICE_CATEGORIES }, if: :fixed_per_unit?

    scope :ordered, -> { order(min_days_before_departure: :desc) }
  end
end
