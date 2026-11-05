# An agency's traveler type, such as Adult or Child (BKG-21). Inactivating a
# type hides it from new choices and never changes a booking.
class TravelerType < ApplicationRecord
  STATUSES = %w[active inactive].freeze
  NAME_LIMIT = 60
  DEFAULT_NAMES = [ "Adult", "Child", "Child 0–4" ].freeze

  belongs_to :agency

  enum :status, STATUSES.index_by(&:itself), validate: true, default: "active"

  attr_readonly :agency_id

  normalizes :name, with: ->(value) { value.to_s.squish }

  validates :name, presence: true, length: { maximum: NAME_LIMIT }
  validates :name, uniqueness: { scope: :agency_id, case_sensitive: false }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :ordered, -> { order(:position, :name) }

  def self.create_defaults!(agency)
    DEFAULT_NAMES.each_with_index do |name, position|
      agency.traveler_types.create!(name:, position:)
    end
  end
end
