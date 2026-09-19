# frozen_string_literal: true

# Staff-recorded planning milestone. Does not store traveler identities or names.
class SupplierPlanningMilestoneOccurrence < ApplicationRecord
  include AppendOnlyRecord

  KINDS = %w[names_assigned_to_supplier].freeze

  belongs_to :agency
  belongs_to :departure
  belongs_to :supplier_arrangement
  belongs_to :supplier_arrangement_version
  belongs_to :actor, class_name: "AgencyUser"
  belongs_to :agency_command_idempotency_key, optional: true

  enum :kind, KINDS.index_by(&:itself), validate: true

  attr_readonly :agency_id, :departure_id, :supplier_arrangement_id,
    :supplier_arrangement_version_id

  validates :recorded_at, presence: true
  validates :note, length: { maximum: 2000 }, allow_nil: true
  validate :precision_exclusivity

  private

  def precision_exclusivity
    valid = (occurred_on.present? && occurred_at.nil?) || (occurred_at.present? && occurred_on.nil?)
    errors.add(:base, "Planning milestone must record either a date or a timestamp") unless valid
  end
end
