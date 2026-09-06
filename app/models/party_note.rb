class PartyNote < ApplicationRecord
  VISIBILITIES = %w[
    standard
    administrator_only
  ].freeze

  RECORD_STATUSES = %w[
    active
    superseded
    removed
  ].freeze

  belongs_to :agency
  belongs_to :party, inverse_of: :notes
  belongs_to :author_membership, class_name: "AgencyMembership", inverse_of: false
  belongs_to :superseded_by_note, class_name: "PartyNote", optional: true, inverse_of: false
  belongs_to :corrected_by_membership, class_name: "AgencyMembership", optional: true, inverse_of: false
  belongs_to :removed_by_membership, class_name: "AgencyMembership", optional: true, inverse_of: false

  enum :visibility, VISIBILITIES.index_by(&:itself), validate: true
  enum :record_status, RECORD_STATUSES.index_by(&:itself), validate: true, prefix: :record

  attr_readonly :agency_id, :party_id, :author_membership_id, :body, :visibility

  validates :body, presence: true
  validate :body_is_allowed

  scope :active_records, -> { record_active }
  scope :historical_records, -> { where(record_status: %w[superseded removed]) }
  scope :visible_to, ->(membership) {
    relation = all
    membership&.administrator? ? relation : relation.standard
  }
  scope :pinned_first, -> { order(pinned: :desc, created_at: :desc, id: :desc) }

  def visibility_label
    administrator_only? ? "Administrator only" : "Standard"
  end

  private

  def body_is_allowed
    violation = PartyNoteContentPolicy.violation_for(body)
    return if violation.blank?

    errors.add(:body, violation)
  end
end
