class ContactPointPurposeAssignment < ApplicationRecord
  PURPOSES = %w[
    general
    correspondence
    billing
  ].freeze

  RECORD_STATUSES = %w[
    valid
    superseded
    voided
  ].freeze

  belongs_to :agency
  belongs_to :party
  belongs_to :contact_point, class_name: "PartyContactPoint", inverse_of: :purpose_assignments
  belongs_to :superseded_by_assignment,
    class_name: "ContactPointPurposeAssignment",
    optional: true,
    inverse_of: false
  belongs_to :corrected_by_membership,
    class_name: "AgencyMembership",
    optional: true,
    inverse_of: false
  belongs_to :ended_by_membership,
    class_name: "AgencyMembership",
    optional: true,
    inverse_of: false

  enum :purpose, PURPOSES.index_by(&:itself), validate: true
  enum :record_status, RECORD_STATUSES.index_by(&:itself), validate: true, prefix: :record

  attr_readonly :agency_id, :party_id, :contact_point_id, :contact_kind

  validates :priority, numericality: { only_integer: true, greater_than: 0 }
  validates :contact_kind, inclusion: { in: PartyContactPoint::KINDS }
  validate :range_order
  validate :party_matches_contact_point
  validate :kind_matches_contact_point
  validate :agency_matches_contact_point

  scope :kept, -> { record_valid }
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

  def primary?
    priority == 1
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

  def party_matches_contact_point
    return if contact_point.blank? || party_id.blank? || contact_point.party_id == party_id

    errors.add(:party, "must match the contact point owner")
  end

  def kind_matches_contact_point
    return if contact_point.blank? || contact_kind.blank? || contact_point.contact_kind == contact_kind

    errors.add(:contact_kind, "must match the contact point")
  end

  def agency_matches_contact_point
    return if contact_point.blank? || agency_id.blank? || contact_point.agency_id == agency_id

    errors.add(:agency, "must match the contact point agency")
  end
end
