# frozen_string_literal: true

class SupplierAttentionFinding < ApplicationRecord
  DETECTOR_KEYS = %w[
    open_commitment_without_future_deadline
    actionable_commitment_due_soon
    actionable_commitment_overdue
    deadline_materialization_incomplete
    deposit_calculation_incomplete
    exposure_incomplete
    unresolved_reservation_response_scope
    capacity_override_or_discrepancy
  ].freeze

  ACTION_GROUPS = %w[
    dispose_or_satisfy_commitment
    resolve_deadline
    complete_deposit_inputs
    inspect_exposure
    resolve_reservation_response
    review_capacity
  ].freeze

  SEVERITIES = %w[attention overdue blocking].freeze

  SOURCE_KINDS = %w[
    supplier_commitment
    supplier_deadline_definition
    supplier_deadline_occurrence
    supplier_deposit_requirement_definition
    supplier_exposure_component
    supplier_reservation
    capacity_pool
    capacity_reconciliation
  ].freeze

  belongs_to :agency
  belongs_to :departure
  belongs_to :supplier_arrangement
  belongs_to :supplier_arrangement_version

  enum :detector_key, DETECTOR_KEYS.index_by(&:itself), validate: true
  enum :action_group, ACTION_GROUPS.index_by(&:itself), validate: true
  enum :severity, SEVERITIES.index_by(&:itself), validate: true
  enum :source_kind, SOURCE_KINDS.index_by(&:itself), validate: true

  attr_readonly :agency_id, :departure_id, :supplier_arrangement_id

  validates :required_action, :reason, :consequence_summary, :primary_path,
    :source_fingerprint, :attention_at, :rebuilt_at, presence: true

  scope :visible_at, ->(at = Time.current) {
    where("attention_at <= ?", at)
  }

  scope :overdue_at, ->(at = Time.current) {
    where("overdue_at IS NOT NULL AND overdue_at <= ?", at)
  }

  def overdue?(at = Time.current)
    overdue_at.present? && overdue_at <= at
  end

  def visible?(at = Time.current)
    attention_at <= at
  end
end
