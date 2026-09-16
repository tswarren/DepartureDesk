class CapacityPairDefinition < ApplicationRecord
  CLASSIFICATIONS = %w[pooled not_applicable].freeze

  belongs_to :agency
  belongs_to :departure
  belongs_to :supplier_arrangement
  belongs_to :supplier_arrangement_version
  belongs_to :arrangement_item
  belongs_to :service_occurrence
  belongs_to :supplier_resource

  has_many :capacity_pool_definitions, dependent: :restrict_with_exception

  enum :classification, CLASSIFICATIONS.index_by(&:itself), validate: true

  attr_readonly :agency_id, :departure_id, :supplier_arrangement_id,
    :supplier_arrangement_version_id, :arrangement_item_id,
    :service_occurrence_id, :supplier_resource_id
end
