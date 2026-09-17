class SupplierCostParticipantCategory < ApplicationRecord
  LABEL_LIMIT = 80

  belongs_to :agency
  belongs_to :departure
  belongs_to :supplier_arrangement
  belongs_to :supplier_arrangement_version
  belongs_to :arrangement_item

  has_many :supplier_cost_components, foreign_key: :participant_category_id,
    dependent: :restrict_with_exception
  has_many :supplier_cost_occupancy_profile_positions,
    foreign_key: :participant_category_id, dependent: :restrict_with_exception

  attr_readonly :agency_id, :departure_id, :supplier_arrangement_id,
    :supplier_arrangement_version_id, :arrangement_item_id

  normalizes :label, with: ->(value) { value.to_s.strip }

  validates :label, presence: true, length: { maximum: LABEL_LIMIT }
  validates :position, numericality: { only_integer: true, greater_than: 0 }
end
