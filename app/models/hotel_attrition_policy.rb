# frozen_string_literal: true

class HotelAttritionPolicy < ApplicationRecord
  include ExactVersionCopyLineage
  include DraftVersionDefinition

  CONSEQUENCES = %w[lost_room_revenue].freeze
  CONSEQUENCE_BASIS_POINTS = 10_000

  belongs_to :agency
  belongs_to :departure
  belongs_to :supplier_arrangement
  belongs_to :supplier_arrangement_version
  belongs_to :arrangement_item

  has_many :hotel_attrition_nights, dependent: :restrict_with_exception
  has_many :hotel_attrition_zero_utilization_rates, dependent: :restrict_with_exception

  enum :consequence, CONSEQUENCES.index_by(&:itself), validate: true

  attr_readonly :agency_id, :departure_id, :supplier_arrangement_id,
    :supplier_arrangement_version_id, :arrangement_item_id, :consequence, :consequence_basis_points

  validates :consequence_basis_points, inclusion: { in: [ CONSEQUENCE_BASIS_POINTS ] }
  validates :quoted_tax_rate_basis_points, numericality: {
    only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 10_000
  }
  validates :arrangement_item_id, uniqueness: { scope: :supplier_arrangement_version_id }
end
