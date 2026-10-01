# frozen_string_literal: true

class SupplierAgreementReference < ApplicationRecord
  include ExactVersionCopyLineage
  include DraftVersionDefinition

  WORDING_LIMIT = 2_000
  KINDS = %w[
    deposit_derivation attrition deposit_refund
    destination_fee additional_nights early_departure cancellation
  ].freeze
  ITEM_KINDS = %w[deposit_derivation attrition deposit_refund].freeze

  belongs_to :agency
  belongs_to :departure
  belongs_to :supplier_arrangement
  belongs_to :supplier_arrangement_version
  belongs_to :arrangement_item, optional: true
  belongs_to :recorded_by, class_name: "AgencyUser"

  enum :kind, KINDS.index_by(&:itself), validate: true

  attr_readonly :agency_id, :departure_id, :supplier_arrangement_id,
    :supplier_arrangement_version_id, :arrangement_item_id, :kind

  normalizes :governing_wording, :original_wording, with: ->(value) { value.to_s.strip.presence }
  normalizes :source_description, with: ->(value) { value.to_s.strip }
  normalizes :supplier_reference, :external_reference, :evidence_note,
    with: ->(value) { value.to_s.strip.presence }

  validates :governing_wording, :source_description, presence: true, length: { maximum: WORDING_LIMIT }
  validates :original_wording, :supplier_reference, :external_reference, :evidence_note,
    length: { maximum: WORDING_LIMIT }, allow_nil: true
  validates :recorded_at, presence: true
  validates :arrangement_item, presence: true, if: :item_required?
  validates :kind, uniqueness: { scope: [ :supplier_arrangement_version_id, :arrangement_item_id ] }
  validate :original_wording_matches_kind

  private

  def item_required?
    ITEM_KINDS.include?(kind)
  end

  def original_wording_matches_kind
    if deposit_refund?
      errors.add(:original_wording, "can't be blank") if original_wording.blank?
    elsif original_wording.present?
      errors.add(:original_wording, "must be blank")
    end
  end
end
