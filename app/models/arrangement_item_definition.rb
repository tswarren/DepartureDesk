class ArrangementItemDefinition < ApplicationRecord
  CATEGORIES = %w[
    cruise
    lodging
    air
    ground_transportation
    dining
    activity_attraction
    insurance
    other
  ].freeze
  NAME_LIMIT = 160
  DESCRIPTION_LIMIT = 2_000
  OTHER_CATEGORY_LABEL_LIMIT = 80

  belongs_to :agency
  belongs_to :departure
  belongs_to :supplier_arrangement
  belongs_to :supplier_arrangement_version
  belongs_to :arrangement_item
  belongs_to :default_service_provider, class_name: "Supplier", optional: true

  attr_readonly :agency_id, :departure_id, :supplier_arrangement_id,
    :supplier_arrangement_version_id, :arrangement_item_id

  normalizes :name, with: ->(value) { value.to_s.strip }
  normalizes :description, :category, :other_category_label,
    with: ->(value) { value.to_s.strip.presence }

  validates :name, presence: true, length: { maximum: NAME_LIMIT }
  validates :description, length: { maximum: DESCRIPTION_LIMIT }, allow_nil: true
  validates :category, presence: true, inclusion: { in: CATEGORIES }
  validates :other_category_label, length: { maximum: OTHER_CATEGORY_LABEL_LIMIT }, allow_nil: true
  validates :position, numericality: { only_integer: true, greater_than: 0 }
  validate :other_label_matches_category

  private

  def other_label_matches_category
    if category == "other"
      errors.add(:other_category_label, "can't be blank") if other_category_label.blank?
    elsif other_category_label.present?
      errors.add(:other_category_label, "must be blank unless category is other")
    end
  end
end
