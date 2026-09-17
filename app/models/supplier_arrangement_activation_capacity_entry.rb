class SupplierArrangementActivationCapacityEntry < ApplicationRecord
  include AppendOnlyRecord

  ENTRY_KINDS = %w[established carried nonnumeric].freeze

  belongs_to :agency
  belongs_to :departure
  belongs_to :supplier_arrangement
  belongs_to :supplier_arrangement_version
  belongs_to :supplier_arrangement_activation
  belongs_to :capacity_pool_definition
  belongs_to :capacity_pool
  belongs_to :establishment_event, class_name: "CapacityEvent", optional: true

  enum :entry_kind, ENTRY_KINDS.index_by(&:itself), validate: true

  attr_readonly :agency_id, :departure_id, :supplier_arrangement_id,
    :supplier_arrangement_version_id, :supplier_arrangement_activation_id

  validate :establishment_event_matches_kind

  private

  def establishment_event_matches_kind
    errors.add(:establishment_event, "must match entry kind") unless
      established? == establishment_event_id.present?
  end
end
