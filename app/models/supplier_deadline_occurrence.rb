# frozen_string_literal: true

class SupplierDeadlineOccurrence < ApplicationRecord
  include AppendOnlyRecord

  DEADLINE_TYPES = SupplierDeadlineDefinition::DEADLINE_TYPES
  KINDS = SupplierDeadlineDefinition::KINDS
  RULE_SHAPES = SupplierDeadlineDefinition::RULE_SHAPES
  PRECISIONS = SupplierDeadlineDefinition::PRECISIONS
  CARDINALITIES = SupplierDeadlineDefinition::CARDINALITIES

  belongs_to :agency
  belongs_to :departure
  belongs_to :supplier_arrangement
  belongs_to :supplier_arrangement_version
  belongs_to :supplier_deadline_definition
  belongs_to :supplier_arrangement_activation, optional: true
  belongs_to :predecessor_occurrence, class_name: "SupplierDeadlineOccurrence", optional: true
  belongs_to :actor, class_name: "AgencyUser"

  has_one :supplier_deadline_projection, dependent: :restrict_with_exception
  has_many :supplier_commitments, dependent: :restrict_with_exception

  enum :deadline_type, DEADLINE_TYPES.index_by(&:itself), validate: true
  enum :kind, KINDS.index_by(&:itself), validate: true
  enum :rule_shape, RULE_SHAPES.index_by(&:itself), validate: true
  enum :precision, PRECISIONS.index_by(&:itself), validate: true
  enum :cardinality, CARDINALITIES.index_by(&:itself), validate: true

  attr_readonly :agency_id, :departure_id, :supplier_arrangement_id,
    :supplier_arrangement_version_id

  validates :materialization_key, :time_zone, :materialized_at, presence: true
  validate :precision_exclusivity

  def current?
    superseded_at.nil?
  end

  def elapsed?(at: Time.current)
    zone = ActiveSupport::TimeZone[time_zone] || Time.find_zone!("UTC")
    if date_only?
      zone.local(calculated_on.year, calculated_on.month, calculated_on.day).end_of_day < at
    else
      calculated_at < at
    end
  end

  def mark_superseded!(at:)
    raise ActiveRecord::RecordInvalid, self if superseded_at.present?

    update_columns(superseded_at: at, updated_at: Time.current)
  end

  private

  def precision_exclusivity
    valid = (date_only? && calculated_on.present? && calculated_at.nil?) ||
      (local_date_time? && calculated_at.present? && calculated_on.nil?)
    errors.add(:base, "Deadline occurrence precision must be exclusive") unless valid
  end
end
