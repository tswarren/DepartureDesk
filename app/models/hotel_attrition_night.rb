# frozen_string_literal: true

class HotelAttritionNight < ApplicationRecord
  include ExactVersionCopyLineage
  include DraftVersionDefinition

  belongs_to :agency
  belongs_to :departure
  belongs_to :supplier_arrangement
  belongs_to :supplier_arrangement_version
  belongs_to :hotel_attrition_policy
  belongs_to :arrangement_item
  belongs_to :service_occurrence

  attr_readonly :agency_id, :departure_id, :supplier_arrangement_id,
    :supplier_arrangement_version_id, :hotel_attrition_policy_id, :arrangement_item_id,
    :service_occurrence_id

  validates :minimum_utilized_room_nights, numericality: { only_integer: true, greater_than: 0 }
  validates :service_occurrence_id, uniqueness: { scope: :hotel_attrition_policy_id }
end
