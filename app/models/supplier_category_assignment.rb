class SupplierCategoryAssignment < ApplicationRecord
  belongs_to :agency
  belongs_to :supplier

  attr_readonly :agency_id, :supplier_id, :category_code

  normalizes :category_code, with: ->(value) { value.to_s.strip.presence }
  normalizes :other_label, with: ->(value) { value.to_s.strip.presence }

  validates :category_code, presence: true, inclusion: { in: SupplierCategory::CODES }
  validates :other_label, length: { maximum: 80 }, allow_nil: true
  validate :other_label_matches_category

  private

  def other_label_matches_category
    if category_code == "other"
      errors.add(:other_label, "can't be blank") if other_label.blank?
    elsif other_label.present?
      errors.add(:other_label, "must be blank unless category is other")
    end
  end
end
