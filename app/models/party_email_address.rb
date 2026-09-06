class PartyEmailAddress < ApplicationRecord
  TYPES = %w[
    personal
    work
    general
    booking
    accounting
    other
  ].freeze

  self.primary_key = "contact_point_id"

  belongs_to :contact_point, class_name: "PartyContactPoint", inverse_of: :email_address
  belongs_to :agency

  attribute :contact_kind, :string, default: "email"
  attr_readonly :contact_kind, :agency_id, :contact_point_id

  enum :email_type, TYPES.index_by(&:itself), validate: true

  normalizes :display_address, :normalized_address, with: ->(value) { value&.strip }

  validates :display_address, :normalized_address, presence: true
  validates :contact_kind, inclusion: { in: %w[email] }
  validate :agency_matches_contact_point

  private

  def agency_matches_contact_point
    return if contact_point.blank? || agency_id.blank? || contact_point.agency_id == agency_id

    errors.add(:agency, "must match the contact point agency")
  end
end
