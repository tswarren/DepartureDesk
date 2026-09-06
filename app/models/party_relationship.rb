class PartyRelationship < ApplicationRecord
  KINDS = %w[
    household_member
    family
    organization_affiliation
    organization_contact
    parent_organization
    service_provider_for
  ].freeze

  FAMILY_LABELS = %w[
    parent_of
    child_of
    guardian_of
    dependent_of
    spouse_of
    partner_of
    other_family
  ].freeze

  AFFILIATION_LABELS = %w[
    employee
    contractor
    owner
    member
    representative
    other
  ].freeze

  RECORD_STATUSES = %w[
    valid
    superseded
    voided
  ].freeze

  PURPOSE_KINDS = %w[
    organization_affiliation
    organization_contact
  ].freeze

  KIND_PAIRS = {
    "household_member" => %w[person household],
    "family" => %w[person person],
    "organization_affiliation" => %w[person organization],
    "organization_contact" => %w[person organization],
    "parent_organization" => %w[organization organization],
    "service_provider_for" => %w[organization organization]
  }.freeze

  belongs_to :agency
  belongs_to :origin_party, class_name: "Party", inverse_of: false
  belongs_to :related_party, class_name: "Party", inverse_of: false
  belongs_to :superseded_by_relationship, class_name: "PartyRelationship", optional: true, inverse_of: false
  belongs_to :corrected_by_membership, class_name: "AgencyMembership", optional: true, inverse_of: false
  belongs_to :ended_by_membership, class_name: "AgencyMembership", optional: true, inverse_of: false

  has_many :purpose_assignments,
    class_name: "RelationshipPurposeAssignment",
    inverse_of: :party_relationship,
    dependent: :restrict_with_exception

  enum :relationship_kind, KINDS.index_by(&:itself), validate: true
  enum :record_status, RECORD_STATUSES.index_by(&:itself), validate: true, prefix: :record

  attr_readonly :agency_id, :origin_party_id, :related_party_id, :origin_party_kind, :related_party_kind, :relationship_kind

  normalizes :title, :notes, :source, with: ->(value) { value&.strip.presence }

  validates :origin_party_kind, :related_party_kind, presence: true
  validate :participants_match_kind
  validate :not_self
  validate :range_order

  scope :involving, ->(party) { where("origin_party_id = :id OR related_party_id = :id", id: party.id) }
  scope :current_on, ->(date) {
    record_valid
      .where("effective_from IS NULL OR effective_from <= ?", date)
      .where("effective_until IS NULL OR effective_until > ?", date)
  }
  scope :upcoming_on, ->(date) { record_valid.where("effective_from > ?", date) }
  scope :historical_on, ->(date) {
    where(
      "record_status IN ('superseded', 'voided') OR (record_status = 'valid' AND effective_until IS NOT NULL AND effective_until <= ?)",
      date
    )
  }

  def current_on?(date)
    record_valid? &&
      (effective_from.blank? || effective_from <= date) &&
      (effective_until.blank? || effective_until > date)
  end

  def purpose_eligible?
    PURPOSE_KINDS.include?(relationship_kind)
  end

  def description
    origin = origin_party.display_name
    related = related_party.display_name
    case relationship_kind
    when "household_member"
      "#{origin} is a member of #{related}."
    when "family"
      family_description(origin, related)
    when "organization_affiliation"
      "#{origin} is affiliated with #{related}."
    when "organization_contact"
      "#{origin} is a contact for #{related}."
    when "parent_organization"
      "#{origin} is operated by #{related}."
    when "service_provider_for"
      "#{origin} provides services through #{related}."
    end
  end

  def self.pair_for(kind)
    KIND_PAIRS.fetch(kind.to_s)
  end

  private

  def family_description(origin, related)
    case relationship_label
    when "parent_of" then "#{origin} is a parent of #{related}."
    when "child_of" then "#{origin} is a child of #{related}."
    when "guardian_of" then "#{origin} is a guardian of #{related}."
    when "dependent_of" then "#{origin} is a dependent of #{related}."
    when "spouse_of" then "#{origin} is a spouse of #{related}."
    when "partner_of" then "#{origin} is a partner of #{related}."
    else "#{origin} has a family relationship with #{related}."
    end
  end

  def participants_match_kind
    expected = KIND_PAIRS[relationship_kind]
    return if expected.blank?
    return if origin_party_kind == expected[0] && related_party_kind == expected[1]

    errors.add(:relationship_kind, "does not match the selected parties")
  end

  def not_self
    return if origin_party_id.blank? || related_party_id.blank? || origin_party_id != related_party_id

    errors.add(:related_party, "cannot be the same party")
  end

  def range_order
    return if effective_from.blank? || effective_until.blank?
    return if effective_until > effective_from

    errors.add(:effective_until, "must be after the start date")
  end
end
