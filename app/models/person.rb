class Person < ApplicationRecord
  self.primary_key = "party_id"

  belongs_to :party, inverse_of: :person
  belongs_to :agency
  has_one :agency_membership,
    foreign_key: :person_party_id,
    inverse_of: :person_party,
    dependent: :restrict_with_exception

  normalizes :given_name, :family_name, with: ->(value) { value&.strip }
  normalizes :middle_name, :prefix, :suffix, :preferred_name, :form_of_address, :pronouns,
    with: ->(value) { value&.strip.presence }

  validates :given_name, :family_name, presence: true
  attribute :party_kind, :string, default: "person"
  attr_readonly :party_kind
  validates :party_kind, inclusion: { in: %w[person] }
  validate :date_of_birth_not_future
  validate :party_is_person_kind
  validate :agency_matches_party

  scope :unlinked, -> { where.missing(:agency_membership) }

  def linked_to_membership?
    agency_membership.present?
  end

  private

  def date_of_birth_not_future
    return if date_of_birth.blank?
    return if date_of_birth <= Date.current

    errors.add(:date_of_birth, "cannot be in the future")
  end

  def party_is_person_kind
    return if party.blank? || party.person?

    errors.add(:party, "must be a person")
  end

  def agency_matches_party
    return if party.blank? || agency_id.blank? || party.agency_id == agency_id

    errors.add(:agency, "must match the party agency")
  end
end
