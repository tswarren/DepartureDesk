class SupplierResourceDefinition < ApplicationRecord
  include ExactVersionCopyLineage
  include DraftVersionDefinition
  NAME_LIMIT = 160
  DESCRIPTION_LIMIT = 2_000

  belongs_to :agency
  belongs_to :departure
  belongs_to :supplier_arrangement
  belongs_to :supplier_arrangement_version
  belongs_to :arrangement_item
  belongs_to :supplier_resource

  attr_readonly :agency_id, :departure_id, :supplier_arrangement_id,
    :supplier_arrangement_version_id, :arrangement_item_id, :supplier_resource_id

  normalizes :name, with: ->(value) { value.to_s.strip }
  normalizes :description, with: ->(value) { value.to_s.strip.presence }

  validates :name, presence: true, length: { maximum: NAME_LIMIT }
  validates :description, length: { maximum: DESCRIPTION_LIMIT }, allow_nil: true
  validates :position, numericality: { only_integer: true, greater_than: 0 }
end
