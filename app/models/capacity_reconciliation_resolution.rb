class CapacityReconciliationResolution < ApplicationRecord
  belongs_to :agency
  belongs_to :departure
  belongs_to :supplier_arrangement
  belongs_to :supplier_arrangement_version
  belongs_to :arrangement_item
  belongs_to :service_occurrence
  belongs_to :supplier_resource
  belongs_to :capacity_pool
  belongs_to :capacity_reconciliation
  belongs_to :capacity_event
  belongs_to :actor, class_name: "AgencyUser"

  attr_readonly :agency_id, :departure_id, :supplier_arrangement_id,
    :supplier_arrangement_version_id, :arrangement_item_id,
    :service_occurrence_id, :supplier_resource_id, :capacity_pool_id,
    :capacity_reconciliation_id, :capacity_event_id, :actor_id, :resolved_at

  normalizes :note, with: ->(value) { value.to_s.strip }

  validates :resolved_at, presence: true
  validates :note, presence: true, length: { maximum: 500 }

  before_update :reject_mutation
  before_destroy :reject_mutation

  private

  def reject_mutation
    errors.add(:base, "capacity reconciliation resolutions are append-only")
    throw :abort
  end
end
