class Organization < ApplicationRecord
  self.primary_key = "party_id"

  belongs_to :party, inverse_of: :organization
  belongs_to :agency

  normalizes :legal_name, with: ->(value) { value&.strip }
  normalizes :trading_name, :website, with: ->(value) { value&.strip.presence }

  validates :legal_name, presence: true
  attribute :party_kind, :string, default: "organization"
  attr_readonly :party_kind
  validates :party_kind, inclusion: { in: %w[organization] }
  validate :party_is_organization_kind
  validate :agency_matches_party

  private

  def party_is_organization_kind
    return if party.blank? || party.organization?

    errors.add(:party, "must be an organization")
  end

  def agency_matches_party
    return if party.blank? || agency_id.blank? || party.agency_id == agency_id

    errors.add(:agency, "must match the party agency")
  end
end
