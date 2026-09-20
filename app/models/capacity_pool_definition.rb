class CapacityPoolDefinition < ApplicationRecord
  include ExactVersionCopyLineage
  include DraftVersionDefinition
  EVIDENCE_KINDS = %w[
    contract
    supplier_confirmation
    supplier_message
    supplier_portal
    verbal_confirmation
    other
  ].freeze
  LABEL_LIMIT = 120
  NOTES_LIMIT = 2_000
  UNIT_LABEL_LIMIT = 40
  EVIDENCE_REFERENCE_NOTE_LIMIT = 500
  EVIDENCE_EXTERNAL_REFERENCE_LIMIT = 160
  OVERRIDE_REASON_LIMIT = 500

  belongs_to :agency
  belongs_to :departure
  belongs_to :supplier_arrangement
  belongs_to :supplier_arrangement_version
  belongs_to :arrangement_item
  belongs_to :service_occurrence
  belongs_to :supplier_resource
  belongs_to :capacity_pair_definition
  belongs_to :capacity_pool
  has_many :service_offer_source_bindings, dependent: :restrict_with_exception

  attr_readonly :agency_id, :departure_id, :supplier_arrangement_id,
    :supplier_arrangement_version_id, :arrangement_item_id,
    :service_occurrence_id, :supplier_resource_id,
    :capacity_pair_definition_id, :capacity_pool_id

  normalizes :label, :normalized_label, :unit_label, with: ->(value) { value.to_s.strip }
  normalizes :notes, :evidence_kind, :evidence_reference_note,
    :evidence_external_reference, :override_reason,
    with: ->(value) { value.to_s.strip.presence }

  validates :label, presence: true, length: { maximum: LABEL_LIMIT }
  validates :normalized_label, presence: true, length: { maximum: LABEL_LIMIT }
  validates :notes, length: { maximum: NOTES_LIMIT }, allow_nil: true
  validates :unit_label, presence: true, length: { maximum: UNIT_LABEL_LIMIT }
  validates :proposed_opening_quantity,
    numericality: { only_integer: true, greater_than: 0 },
    allow_nil: true
  validates :evidence_kind, inclusion: { in: EVIDENCE_KINDS }, allow_nil: true
  validates :evidence_reference_note,
    length: { maximum: EVIDENCE_REFERENCE_NOTE_LIMIT },
    allow_nil: true
  validates :evidence_external_reference,
    length: { maximum: EVIDENCE_EXTERNAL_REFERENCE_LIMIT },
    allow_nil: true
  validates :override_reason, length: { maximum: OVERRIDE_REASON_LIMIT }, allow_nil: true
  validates :position, numericality: { only_integer: true, greater_than: 0 }
  validate :normalized_label_matches_label
  validate :evidence_or_override_is_consistent

  private

  def normalized_label_matches_label
    return if label.blank? || normalized_label.blank?
    return if normalized_label == label.downcase.strip

    errors.add(:normalized_label, "must match the normalized label")
  end

  def evidence_or_override_is_consistent
    ordinary_fields = [ evidence_kind, evidence_on, evidence_reference_note ]

    if override?
      errors.add(:override_reason, "can't be blank") if override_reason.blank?
      errors.add(:base, "Override cannot include supplier evidence") if ordinary_fields.any?(&:present?) || evidence_external_reference.present?
    elsif override_reason.present?
      errors.add(:override_reason, "must be blank without override")
    elsif ordinary_fields.any?(&:present?) || evidence_external_reference.present?
      errors.add(:base, "Enter complete supplier evidence") unless ordinary_fields.all?(&:present?)
    end
  end
end
