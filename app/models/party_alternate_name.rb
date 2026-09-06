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
  belongs_to :removed_by_membership,
    class_name: "AgencyMembership",
    optional: true,
    inverse_of: false

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
  validate :removal_matches_status
  validate :removal_actor_same_agency

  scope :visible, -> { active }

  def remove!(removed_at:, removed_by_membership:)
    update!(
      status: "removed",
      removed_at: removed_at,
      removed_by_membership: removed_by_membership
    )
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

  def removal_matches_status
    if active?
      errors.add(:removed_at, "must be blank") if removed_at.present?
      errors.add(:removed_by_membership_id, "must be blank") if removed_by_membership_id.present?
    elsif removed?
      errors.add(:removed_at, "must be present") if removed_at.blank?
      errors.add(:removed_by_membership_id, "must be present") if removed_by_membership_id.blank?
    end
  end

  def removal_actor_same_agency
    return if removed_by_membership.blank? || agency_id.blank?
    return if removed_by_membership.agency_id == agency_id

    errors.add(:removed_by_membership, "must belong to the same agency")
  end
end
