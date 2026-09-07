class SupplierServiceCategoryAssignment < ApplicationRecord
  CATEGORY_CODES = %w[
    accommodation
    air
    cruise
    rail
    ground_transportation
    tour_operator
    activity
    venue
    dining
    insurance
    destination_management
  ].freeze

  belongs_to :agency
  belongs_to :supplier_profile, inverse_of: :service_category_assignments

  validates :category_code, inclusion: { in: CATEGORY_CODES }
  validate :same_agency_profile

  def category_label
    category_code.tr("_", " ").titleize
  end

  private

  def same_agency_profile
    return if supplier_profile.blank? || agency_id.blank?
    return if supplier_profile.agency_id == agency_id

    errors.add(:supplier_profile, "must belong to the same agency")
  end
end
