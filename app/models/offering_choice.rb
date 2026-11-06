# One choice in an offering (BKG-14 to BKG-16): included (changing it means
# picking another option) or an add-on (it only adds a service), made per
# traveler, per unit or per trip, with one of three patterns. Optional
# multiple applies only to add-ons.
class OfferingChoice < ApplicationRecord
  ROLES = %w[included add_on].freeze
  SCOPES = %w[per_traveler per_unit per_trip].freeze
  PATTERNS = %w[required_single optional_single optional_multiple].freeze

  belongs_to :agency
  belongs_to :offering
  has_many :options, -> { order(:position, :created_at) }, class_name: "OfferingOption", inverse_of: :choice,
    foreign_key: :offering_choice_id, dependent: :restrict_with_exception

  enum :role, ROLES.index_by(&:itself), validate: true
  enum :scope, SCOPES.index_by(&:itself), validate: true, prefix: :made
  enum :pattern, PATTERNS.index_by(&:itself), validate: true

  attr_readonly :agency_id, :offering_id

  normalizes :name, with: ->(value) { value.to_s.squish }

  validates :name, presence: true, length: { maximum: Offering::NAME_LIMIT }
  validate :multiple_only_for_add_ons

  private

  def multiple_only_for_add_ons
    errors.add(:pattern, "optional multiple applies only to add-ons") if optional_multiple? && included?
  end
end
