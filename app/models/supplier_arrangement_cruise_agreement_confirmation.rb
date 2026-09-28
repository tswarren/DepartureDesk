# frozen_string_literal: true

class SupplierArrangementCruiseAgreementConfirmation < ApplicationRecord
  include DraftVersionDefinition

  STATUSES = %w[provisional confirmed].freeze
  REFERENCE_LIMIT = 80
  NOTE_LIMIT = 2_000

  belongs_to :agency
  belongs_to :departure
  belongs_to :supplier_arrangement
  belongs_to :supplier_arrangement_version
  belongs_to :confirmed_by, class_name: "AgencyUser", optional: true
  belongs_to :corrects, class_name: "SupplierArrangementCruiseAgreementConfirmation", optional: true

  enum :status, STATUSES.index_by(&:itself), validate: true

  attr_readonly :agency_id, :departure_id, :supplier_arrangement_id,
    :supplier_arrangement_version_id, :corrects_id

  normalizes :group_reference, with: ->(value) { value.to_s.strip.presence }
  normalizes :note, with: ->(value) { value.to_s.strip.presence }
  normalizes :deposit_treatment, with: ->(value) { value.to_s.strip.presence }

  validates :group_creation_date, presence: true
  validates :group_reference, length: { maximum: REFERENCE_LIMIT }, allow_nil: true
  validates :note, :deposit_treatment, length: { maximum: NOTE_LIMIT }, allow_nil: true
  validate :confirmed_fields_match_status

  private

  def confirmed_fields_match_status
    if confirmed?
      errors.add(:group_reference, "is required") if group_reference.blank?
      errors.add(:contract_date, "is required") if contract_date.blank?
      errors.add(:confirmed_at, "is required") if confirmed_at.blank?
      errors.add(:confirmed_by, "is required") if confirmed_by_id.blank?
    elsif provisional?
      errors.add(:confirmed_at, "must be blank") if confirmed_at.present?
      errors.add(:confirmed_by, "must be blank") if confirmed_by_id.present?
    end
  end
end
