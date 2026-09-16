class CapacityEvent < ApplicationRecord
  EVENT_TYPES = %w[
    established
    increased
    released
    reinstated
    withdrawn
    corrected_up
    corrected_down
  ].freeze
  MEASUREMENT_BASES = CapacityPool::MEASUREMENT_BASES
  EVIDENCE_KINDS = CapacityPoolDefinition::EVIDENCE_KINDS

  belongs_to :agency
  belongs_to :departure
  belongs_to :supplier_arrangement
  belongs_to :supplier_arrangement_version
  belongs_to :arrangement_item
  belongs_to :service_occurrence
  belongs_to :supplier_resource
  belongs_to :capacity_pool
  belongs_to :supplying_supplier, class_name: "Supplier"
  belongs_to :reinstates_event, class_name: "CapacityEvent", optional: true
  belongs_to :corrects_event, class_name: "CapacityEvent", optional: true
  belongs_to :capacity_reconciliation, optional: true
  belongs_to :actor, class_name: "AgencyUser"
  belongs_to :agency_command_idempotency_key, optional: true

  has_many :reinstatement_events,
    class_name: "CapacityEvent",
    foreign_key: :reinstates_event_id,
    dependent: :restrict_with_exception,
    inverse_of: :reinstates_event
  has_many :correction_events,
    class_name: "CapacityEvent",
    foreign_key: :corrects_event_id,
    dependent: :restrict_with_exception,
    inverse_of: :corrects_event

  enum :event_type, EVENT_TYPES.index_by(&:itself), validate: true
  enum :measurement_basis, MEASUREMENT_BASES.index_by(&:itself), validate: true

  attr_readonly :agency_id, :departure_id, :supplier_arrangement_id,
    :supplier_arrangement_version_id, :arrangement_item_id, :capacity_pool_id,
    :service_occurrence_id, :supplier_resource_id, :supplying_supplier_id,
    :event_type, :quantity, :measurement_basis, :effective_on,
    :effective_time_zone, :applies_at, :effective_sequence, :recorded_at,
    :evidence_kind, :evidence_on, :evidence_reference_note,
    :evidence_external_reference, :override, :override_reason,
    :reinstates_event_id, :corrects_event_id, :capacity_reconciliation_id,
    :actor_id, :agency_command_idempotency_key_id

  normalizes :effective_time_zone, :evidence_kind, :evidence_reference_note,
    :evidence_external_reference, :override_reason,
    with: ->(value) { value.to_s.strip.presence }

  validates :quantity, numericality: { only_integer: true, greater_than: 0 }
  validates :effective_on, :effective_time_zone, :applies_at, :recorded_at, presence: true
  validates :effective_sequence, numericality: { only_integer: true, greater_than: 0 }
  validates :evidence_kind, inclusion: { in: EVIDENCE_KINDS }, allow_nil: true
  validate :evidence_or_override_is_consistent
  validate :lineage_matches_event_type

  before_update :reject_mutation
  before_destroy :reject_mutation

  private

  def evidence_or_override_is_consistent
    ordinary_fields = [ evidence_kind, evidence_on, evidence_reference_note ]

    if override?
      errors.add(:override_reason, "can't be blank") if override_reason.blank?
      errors.add(:base, "Override cannot include supplier evidence") if ordinary_fields.any?(&:present?) || evidence_external_reference.present?
    elsif override_reason.present?
      errors.add(:override_reason, "must be blank without override")
    elsif ordinary_fields.any?(&:present?) || evidence_external_reference.present?
      errors.add(:base, "Enter complete supplier evidence") unless ordinary_fields.all?(&:present?)
    else
      errors.add(:base, "Supplier evidence or override is required")
    end
  end

  def lineage_matches_event_type
    errors.add(:reinstates_event, "is required") if reinstated? && reinstates_event_id.blank?
    errors.add(:reinstates_event, "must be blank") if !reinstated? && reinstates_event_id.present?

    unless corrected_up? || corrected_down?
      errors.add(:base, "Only corrections can reference correction sources") if corrects_event_id.present? || capacity_reconciliation_id.present?
      return
    end

    if corrects_event_id.present? == capacity_reconciliation_id.present?
      errors.add(:base, "Correction must reference exactly one source")
    end
  end

  def reject_mutation
    errors.add(:base, "capacity events are append-only")
    throw :abort
  end
end
