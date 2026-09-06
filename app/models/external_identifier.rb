class ExternalIdentifier < ApplicationRecord
  STATUSES = %w[
    active
    inactive
  ].freeze
  SOURCES = %w[
    staff
  ].freeze

  belongs_to :agency
  belongs_to :party, optional: true
  belongs_to :client_profile, optional: true
  belongs_to :supplier_profile, optional: true
  belongs_to :deactivated_by_membership, class_name: "AgencyMembership", optional: true, inverse_of: false

  enum :status, STATUSES.index_by(&:itself), validate: true
  enum :source, SOURCES.index_by(&:itself), validate: true

  attr_readonly :agency_id, :party_id, :client_profile_id, :supplier_profile_id,
    :identifier_type, :issuer, :original_value, :normalized_value, :normalization_version,
    :source

  normalizes :issuer, :original_value, with: ->(value) { value&.strip.presence }
  normalizes :deactivation_reason, with: ->(value) { value&.strip.presence }

  validates :identifier_type, inclusion: { in: ExternalIdentifierRegistry.codes }
  validates :original_value, :normalized_value, presence: true
  validates :normalization_version, numericality: { only_integer: true, greater_than: 0 }
  validate :registry_contract
  validate :lifecycle_complete
  validate :office_must_be_blank

  scope :current, -> { active }
  scope :history, -> { inactive }

  def type_definition
    ExternalIdentifierRegistry.type!(identifier_type)
  end

  def owner_party
    party || client_profile&.party || supplier_profile&.party
  end

  def current_for_role?
    return false unless active?
    return true if party_id.present?
    return client_profile&.active? if client_profile_id.present?
    return supplier_profile&.active? if supplier_profile_id.present?

    false
  end

  def masked_value
    value = original_value.to_s
    return value if value.length <= 4

    "#{value[0, 2]}…#{value[-2, 2]}"
  end

  private

  def registry_contract
    return unless ExternalIdentifierRegistry.known?(identifier_type)

    definition = type_definition
    owner_column = ExternalIdentifierRegistry.owner_column(identifier_type)
    %i[party_id client_profile_id supplier_profile_id].each do |column|
      if column == owner_column
        errors.add(column, "must be present") if public_send(column).blank?
      elsif public_send(column).present?
        errors.add(column, "must be blank")
      end
    end
    if definition.issuer_required && issuer.blank?
      errors.add(:issuer, "must be present")
    end
    errors.add(:office_id, "must be blank") if definition.office_context_allowed == false && office_id.present?
  end

  def lifecycle_complete
    if active?
      errors.add(:deactivated_at, "must be blank") if deactivated_at.present?
      errors.add(:deactivated_by_membership_id, "must be blank") if deactivated_by_membership_id.present?
      errors.add(:deactivation_reason, "must be blank") if deactivation_reason.present?
    elsif inactive?
      errors.add(:deactivated_at, "must be present") if deactivated_at.blank?
      errors.add(:deactivated_by_membership_id, "must be present") if deactivated_by_membership_id.blank?
      errors.add(:deactivation_reason, "must be present") if deactivation_reason.blank?
    end
  end

  def office_must_be_blank
    errors.add(:office_id, "must be blank") if office_id.present?
  end
end
