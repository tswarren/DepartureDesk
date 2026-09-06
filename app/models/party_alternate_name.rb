class PartyAlternateName < ApplicationRecord
  KINDS = %w[
    former_name
    alias
    additional_trading_name
    acronym
    imported_name
  ].freeze

  STATUSES = %w[
    active
    removed
  ].freeze

  belongs_to :party, inverse_of: :alternate_names
  belongs_to :agency

  enum :name_kind, KINDS.index_by(&:itself), validate: true
  enum :status, STATUSES.index_by(&:itself), validate: true

  normalizes :name, with: ->(value) { value&.strip }

  before_validation :assign_normalized_name

  validates :name, :normalized_name, presence: true
  validates :normalized_name, uniqueness: {
    scope: [ :party_id, :name_kind ],
    conditions: -> { where(status: "active") },
    if: :active?,
    message: "is already recorded for this party"
  }
  validate :does_not_duplicate_canonical_name, if: :active?

  scope :visible, -> { active }

  def remove!
    update!(status: "removed")
  end

  private

  def assign_normalized_name
    self.normalized_name = PartyName.normalize(name)
  end

  def does_not_duplicate_canonical_name
    return if party.blank? || normalized_name.blank?

    canonical = PartyName.normalize(party.display_name)
    return if canonical.blank? || canonical != normalized_name

    errors.add(:name, "matches the canonical name")
  end
end
