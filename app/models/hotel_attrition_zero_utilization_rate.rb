# frozen_string_literal: true

class HotelAttritionZeroUtilizationRate < ApplicationRecord
  include ExactVersionCopyLineage
  include DraftVersionDefinition

  belongs_to :agency
  belongs_to :departure
  belongs_to :supplier_arrangement
  belongs_to :supplier_arrangement_version
  belongs_to :hotel_attrition_policy
  belongs_to :arrangement_item
  belongs_to :supplier_resource

  attr_readonly :agency_id, :departure_id, :supplier_arrangement_id,
    :supplier_arrangement_version_id, :hotel_attrition_policy_id, :arrangement_item_id,
    :supplier_resource_id

  validates :amount_minor_units, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :supplier_resource_id, uniqueness: { scope: :hotel_attrition_policy_id }
end
