class SupplierResourceDefinition < ApplicationRecord
  include ExactVersionCopyLineage
  include DraftVersionDefinition
  NAME_LIMIT = 160
  DESCRIPTION_LIMIT = 2_000
  SUPPLIER_CODE_LIMIT = 80

  belongs_to :agency
  belongs_to :departure
  belongs_to :supplier_arrangement
  belongs_to :supplier_arrangement_version
  belongs_to :arrangement_item
  belongs_to :supplier_resource
  has_many :service_offer_source_bindings, dependent: :restrict_with_exception

  attr_readonly :agency_id, :departure_id, :supplier_arrangement_id,
    :supplier_arrangement_version_id, :arrangement_item_id, :supplier_resource_id

  normalizes :name, with: ->(value) { value.to_s.strip }
  normalizes :description, with: ->(value) { value.to_s.strip.presence }
  normalizes :supplier_code, with: ->(value) { value.to_s.strip.presence }

  validates :name, presence: true, length: { maximum: NAME_LIMIT }
  validates :description, length: { maximum: DESCRIPTION_LIMIT }, allow_nil: true
  validates :supplier_code, length: { maximum: SUPPLIER_CODE_LIMIT }, allow_nil: true,
    uniqueness: {
      scope: [ :supplier_arrangement_version_id, :arrangement_item_id ],
      case_sensitive: false,
      allow_nil: true
    }
  validates :maximum_occupancy,
    numericality: { only_integer: true, greater_than: 0 },
    allow_nil: true
  validates :position, numericality: { only_integer: true, greater_than: 0 }
end
