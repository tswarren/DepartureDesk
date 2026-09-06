class Household < ApplicationRecord
  self.primary_key = "party_id"

  belongs_to :party, inverse_of: :household
  belongs_to :agency

  normalizes :name, with: ->(value) { value&.strip }
  normalizes :correspondence_name, with: ->(value) { value&.strip.presence }

  validates :name, presence: true
  validate :party_is_household_kind
  validate :agency_matches_party

  private

  def party_is_household_kind
    return if party.blank? || party.household?

    errors.add(:party, "must be a household")
  end

  def agency_matches_party
    return if party.blank? || agency_id.blank? || party.agency_id == agency_id

    errors.add(:agency, "must match the party agency")
  end
end
