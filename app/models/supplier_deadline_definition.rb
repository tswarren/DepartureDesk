# frozen_string_literal: true

class SupplierDeadlineDefinition < ApplicationRecord
  include DraftVersionDefinition

  DEADLINE_TYPES = %w[
    deposit_due option_or_release_date rooming_list_due legal_names_due final_count_due
    final_schedule_or_departure_time_due cancellation_cutoff accessibility_confirmation_due other
  ].freeze
  KINDS = %w[actionable informational].freeze
  RULE_SHAPES = %w[
    fixed_date fixed_local_datetime days_before_departure days_after_departure
    hours_before_departure hours_after_departure earlier_of later_of
  ].freeze
  PRECISIONS = %w[date_only local_date_time].freeze
  CARDINALITIES = %w[one_shared per_source].freeze
  DESCRIPTION_LIMIT = 500
  OTHER_LABEL_LIMIT = 120

  belongs_to :agency
  belongs_to :departure
  belongs_to :supplier_arrangement
  belongs_to :supplier_arrangement_version
  belongs_to :copied_from, class_name: "SupplierDeadlineDefinition", optional: true

  has_many :supplier_deadline_definition_coverage_links, dependent: :restrict_with_exception
  has_many :supplier_deadline_commitment_definition_lines, dependent: :restrict_with_exception
  has_many :supplier_deadline_occurrences, dependent: :restrict_with_exception

  enum :deadline_type, DEADLINE_TYPES.index_by(&:itself), validate: true
  enum :kind, KINDS.index_by(&:itself), validate: true
  enum :rule_shape, RULE_SHAPES.index_by(&:itself), validate: true
  enum :precision, PRECISIONS.index_by(&:itself), validate: true
  enum :cardinality, CARDINALITIES.index_by(&:itself), validate: true

  attr_readonly :agency_id, :departure_id, :supplier_arrangement_id,
    :supplier_arrangement_version_id, :copied_from_id

  normalizes :description, with: ->(value) { value.to_s.strip.presence }
  normalizes :other_label, with: ->(value) { value.to_s.strip.presence }
  normalizes :time_zone, with: ->(value) { value.to_s.strip }

  validates :position, numericality: { only_integer: true, greater_than: 0 }
  validates :warning_lead_days, numericality: { only_integer: true, greater_than_or_equal_to: 0 },
    allow_nil: true
  validates :description, length: { maximum: DESCRIPTION_LIMIT }, allow_nil: true
  validates :other_label, length: { maximum: OTHER_LABEL_LIMIT }, allow_nil: true
  validates :time_zone, presence: true
  validate :timezone_is_iana
  validate :other_label_matches_type
  validate :actionable_lines_allowed

  def display_label
    deadline_type == "other" ? other_label : deadline_type.humanize
  end

  private

  def timezone_is_iana
    return if time_zone.blank?

    TZInfo::Timezone.get(time_zone)
  rescue TZInfo::InvalidTimezoneIdentifier
    errors.add(:time_zone, "is not a recognized IANA timezone")
  end

  def other_label_matches_type
    if deadline_type == "other"
      errors.add(:other_label, "can't be blank") if other_label.blank?
    elsif other_label.present?
      errors.add(:other_label, "must be blank unless type is other")
    end
  end

  def actionable_lines_allowed
    return unless informational? && supplier_deadline_commitment_definition_lines.any?

    errors.add(:base, "Informational deadlines cannot open commitments")
  end
end
