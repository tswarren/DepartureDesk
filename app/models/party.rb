class Party < ApplicationRecord
  KINDS = %w[
    person
    household
    organization
  ].freeze

  STATUSES = %w[
    active
    deactivated
  ].freeze

  belongs_to :agency
  belongs_to :deactivated_by_membership,
    class_name: "AgencyMembership",
    optional: true,
    inverse_of: false

  has_one :person,
    foreign_key: :party_id,
    inverse_of: :party,
    dependent: :restrict_with_exception
  has_one :household,
    foreign_key: :party_id,
    inverse_of: :party,
    dependent: :restrict_with_exception
  has_one :organization,
    foreign_key: :party_id,
    inverse_of: :party,
    dependent: :restrict_with_exception
  has_many :alternate_names,
    class_name: "PartyAlternateName",
    inverse_of: :party,
    dependent: :restrict_with_exception

  enum :party_kind, KINDS.index_by(&:itself), validate: true
  enum :status, STATUSES.index_by(&:itself), validate: true

  attr_readonly :agency_id, :party_kind

  normalizes :display_name, :sort_name, with: ->(value) { value&.strip }

  validates :display_name, :sort_name, presence: true
  validate :deactivation_matches_status
  validate :deactivation_actor_same_agency

  def kind_profile
    case party_kind
    when "person" then person
    when "household" then household
    when "organization" then organization
    end
  end

  def kind_label
    party_kind.titleize
  end

  def apply_derived_names!(profile = kind_profile)
    names = derived_names_from(profile)
    self.display_name = names.display_name
    self.sort_name = names.sort_name
  end

  def derived_names_from(profile)
    case party_kind
    when "person"
      PartyName.person(
        given_name: profile.given_name,
        family_name: profile.family_name,
        preferred_name: profile.preferred_name,
        middle_name: profile.middle_name
      )
    when "household"
      PartyName.household(name: profile.name)
    when "organization"
      PartyName.organization(
        legal_name: profile.legal_name,
        trading_name: profile.trading_name
      )
    else
      raise ArgumentError, "Unknown party kind"
    end
  end

  private

  def deactivation_matches_status
    if active?
      errors.add(:deactivated_at, "must be blank") if deactivated_at.present?
      errors.add(:deactivated_by_membership_id, "must be blank") if deactivated_by_membership_id.present?
      errors.add(:deactivation_reason, "must be blank") if deactivation_reason.present?
    elsif deactivated?
      errors.add(:deactivated_at, "must be present") if deactivated_at.blank?
      errors.add(:deactivated_by_membership_id, "must be present") if deactivated_by_membership_id.blank?
      errors.add(:deactivation_reason, "must be present") if deactivation_reason.blank?
    end
  end

  def deactivation_actor_same_agency
    return if deactivated_by_membership.blank? || agency_id.blank?
    return if deactivated_by_membership.agency_id == agency_id

    errors.add(:deactivated_by_membership, "must belong to the same agency")
  end
end
