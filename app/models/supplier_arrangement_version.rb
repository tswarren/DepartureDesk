class SupplierArrangementVersion < ApplicationRecord
  STATUSES = %w[draft activated superseded abandoned].freeze
  ABANDONED_REASON_LIMIT = 500
  ALLOWED_LIFECYCLE_TRANSITIONS = {
    "draft" => %w[activated abandoned],
    "activated" => %w[superseded]
  }.freeze

  belongs_to :agency
  belongs_to :departure
  belongs_to :supplier_arrangement
  belongs_to :copied_from, class_name: "SupplierArrangementVersion", optional: true

  has_many :arrangement_item_definitions, dependent: :restrict_with_exception
  has_many :service_occurrence_definitions, dependent: :restrict_with_exception
  has_many :supplier_resource_definitions, dependent: :restrict_with_exception
  has_many :capacity_pair_definitions, dependent: :restrict_with_exception
  has_many :capacity_pool_definitions, dependent: :restrict_with_exception
  has_many :capacity_events, dependent: :restrict_with_exception
  has_many :capacity_reconciliations, dependent: :restrict_with_exception
  has_many :capacity_reconciliation_resolutions, dependent: :restrict_with_exception
  has_many :supplier_cost_sources, dependent: :restrict_with_exception
  has_many :supplier_cost_definitions, dependent: :restrict_with_exception
  has_many :supplier_cost_components, dependent: :restrict_with_exception
  has_many :supplier_cost_participant_categories, dependent: :restrict_with_exception
  has_many :supplier_cost_usage_assumptions, dependent: :restrict_with_exception
  has_many :supplier_cost_occupancy_profiles, dependent: :restrict_with_exception
  has_many :supplier_commitment_trigger_definitions, dependent: :restrict_with_exception
  has_many :supplier_deadline_definitions, dependent: :restrict_with_exception
  has_many :supplier_deadline_definition_coverage_links, dependent: :restrict_with_exception
  has_many :supplier_deadline_commitment_definition_lines, dependent: :restrict_with_exception
  has_many :supplier_deadline_occurrences, dependent: :restrict_with_exception
  has_many :supplier_deadline_projections, dependent: :restrict_with_exception
  has_many :supplier_deposit_requirement_definitions, dependent: :restrict_with_exception
  has_many :supplier_deposit_requirement_definition_coverage_links, dependent: :restrict_with_exception
  has_many :supplier_deposit_requirement_definition_cost_links, dependent: :restrict_with_exception
  has_many :supplier_deposit_requirement_tranches, dependent: :restrict_with_exception
  has_many :supplier_planning_milestone_occurrences, dependent: :restrict_with_exception
  has_one :supplier_arrangement_activation, dependent: :restrict_with_exception
  has_many :supplier_confirmations, dependent: :restrict_with_exception
  has_many :supplier_commitments, dependent: :restrict_with_exception
  has_many :supplier_reservation_revisions, dependent: :restrict_with_exception
  has_many :supplier_reservation_scopes, dependent: :restrict_with_exception
  has_many :supplier_reservation_events, dependent: :restrict_with_exception

  enum :status, STATUSES.index_by(&:itself), validate: true, default: "draft"

  attr_readonly :agency_id, :departure_id, :supplier_arrangement_id, :version_number,
    :copied_from_id

  normalizes :abandoned_reason, with: ->(value) { value.to_s.strip.presence }

  validates :version_number, numericality: { only_integer: true, greater_than: 0 }
  validates :abandoned_reason, length: { maximum: ABANDONED_REASON_LIMIT }, allow_nil: true
  validate :abandonment_fields_match_status
  validate :lifecycle_timestamps_match_status
  validate :lifecycle_transition_is_permitted, on: :update

  private

  def abandonment_fields_match_status
    if abandoned?
      errors.add(:abandoned_at, "can't be blank") if abandoned_at.blank?
      errors.add(:abandoned_reason, "can't be blank") if abandoned_reason.blank?
    else
      errors.add(:abandoned_at, "must be blank unless abandoned") if abandoned_at.present?
      errors.add(:abandoned_reason, "must be blank unless abandoned") if abandoned_reason.present?
    end
  end

  def lifecycle_timestamps_match_status
    valid = case status
    when "activated" then activated_at.present? && superseded_at.nil?
    when "superseded" then activated_at.present? && superseded_at.present? && superseded_at >= activated_at
    else activated_at.nil? && superseded_at.nil?
    end
    errors.add(:base, "Lifecycle timestamps do not match status") unless valid
  end

  def lifecycle_transition_is_permitted
    return unless status_changed?

    from = status_was
    to = status
    allowed = ALLOWED_LIFECYCLE_TRANSITIONS.fetch(from, [])
    return if allowed.include?(to)

    errors.add(:status, "transition from #{from} to #{to} is not permitted")
  end
end
