class RelationshipPurposeAssignment < ApplicationRecord
  PURPOSES = %w[
    general
    booking
    accounting
  ].freeze

  RECORD_STATUSES = %w[
    valid
    superseded
    voided
  ].freeze

  belongs_to :agency
  belongs_to :party_relationship, foreign_key: :relationship_id, inverse_of: :purpose_assignments
  belongs_to :organization_party, class_name: "Party", inverse_of: false
  belongs_to :superseded_by_assignment, class_name: "RelationshipPurposeAssignment", optional: true, inverse_of: false
  belongs_to :corrected_by_membership, class_name: "AgencyMembership", optional: true, inverse_of: false
  belongs_to :ended_by_membership, class_name: "AgencyMembership", optional: true, inverse_of: false

  enum :purpose, PURPOSES.index_by(&:itself), validate: true
  enum :record_status, RECORD_STATUSES.index_by(&:itself), validate: true, prefix: :record

  attr_readonly :agency_id, :relationship_id, :organization_party_id

  validates :priority, numericality: { only_integer: true, greater_than: 0 }
  validate :range_order
  validate :organization_matches_relationship

  scope :current_on, ->(date) {
    record_valid
      .where("effective_from IS NULL OR effective_from <= ?", date)
      .where("effective_until IS NULL OR effective_until > ?", date)
  }
  scope :primary, -> { where(priority: 1) }

  def current_on?(date)
    record_valid? &&
      (effective_from.blank? || effective_from <= date) &&
      (effective_until.blank? || effective_until > date)
  end

  def purpose_label
    purpose.titleize
  end

  private

  def range_order
    return if effective_from.blank? || effective_until.blank?
    return if effective_until > effective_from

    errors.add(:effective_until, "must be after the start date")
  end

  def organization_matches_relationship
    return if party_relationship.blank? || organization_party_id.blank?
    return if party_relationship.related_party_id == organization_party_id

    errors.add(:organization_party, "must match the relationship organization")
  end
end
