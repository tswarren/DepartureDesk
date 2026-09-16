class CapacityReconciliation < ApplicationRecord
  EVIDENCE_KINDS = CapacityPoolDefinition::EVIDENCE_KINDS

  belongs_to :agency
  belongs_to :departure
  belongs_to :supplier_arrangement
  belongs_to :supplier_arrangement_version
  belongs_to :arrangement_item
  belongs_to :service_occurrence
  belongs_to :supplier_resource
  belongs_to :capacity_pool
  belongs_to :actor, class_name: "AgencyUser"
  belongs_to :agency_command_idempotency_key, optional: true

  has_many :capacity_events, dependent: :restrict_with_exception
  has_many :resolutions,
    class_name: "CapacityReconciliationResolution",
    dependent: :restrict_with_exception

  attr_readonly :agency_id, :departure_id, :supplier_arrangement_id,
    :supplier_arrangement_version_id, :arrangement_item_id,
    :service_occurrence_id, :supplier_resource_id, :capacity_pool_id,
    :observed_quantity, :observed_at, :observed_time_zone, :ledger_quantity,
    :variance, :evidence_kind, :evidence_on, :evidence_reference_note,
    :evidence_external_reference, :override, :override_reason, :actor_id,
    :recorded_at, :agency_command_idempotency_key_id

  normalizes :observed_time_zone, :evidence_kind, :evidence_reference_note,
    :evidence_external_reference, :override_reason,
    with: ->(value) { value.to_s.strip.presence }

  validates :observed_quantity, :ledger_quantity,
    numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :observed_at, :observed_time_zone, :recorded_at, presence: true
  validates :evidence_kind, inclusion: { in: EVIDENCE_KINDS }, allow_nil: true
  validate :variance_matches_quantities
  validate :evidence_or_override_is_consistent

  before_update :reject_mutation
  before_destroy :reject_mutation

  def matched?
    variance.zero?
  end

  def resolved?
    !matched? && resolution_quantity == variance
  end

  def open_discrepancy?
    !matched? && !resolved?
  end

  def status
    return "matched" if matched?
    return "resolved" if resolved?

    "open_discrepancy"
  end

  def resolution_quantity
    resolutions.includes(:capacity_event).sum do |resolution|
      event = resolution.capacity_event
      CapacityTimelineReplay::DIRECTIONS.fetch(event.event_type).sign * event.quantity
    end
  end

  private

  def variance_matches_quantities
    return if observed_quantity.blank? || ledger_quantity.blank?
    return if variance == observed_quantity - ledger_quantity

    errors.add(:variance, "must equal observed quantity minus ledger quantity")
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
    else
      errors.add(:base, "Supplier evidence or override is required")
    end
  end

  def reject_mutation
    errors.add(:base, "capacity reconciliations are append-only")
    throw :abort
  end
end
