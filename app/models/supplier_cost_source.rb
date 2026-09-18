class SupplierCostSource < ApplicationRecord
  include ExactVersionCopyLineage
  include DraftVersionDefinition
  LABEL_LIMIT = 160
  NOTES_LIMIT = 2_000

  belongs_to :agency
  belongs_to :departure
  belongs_to :supplier_arrangement
  belongs_to :supplier_arrangement_version
  belongs_to :arrangement_item, optional: true
  belongs_to :service_occurrence, optional: true
  belongs_to :supplier_resource, optional: true
  belongs_to :charging_supplier, class_name: "Supplier"

  has_many :supplier_cost_definitions, dependent: :restrict_with_exception

  attr_readonly :agency_id, :departure_id, :supplier_arrangement_id,
    :supplier_arrangement_version_id, :arrangement_item_id,
    :service_occurrence_id, :supplier_resource_id, :charging_supplier_id

  normalizes :label, with: ->(value) { value.to_s.strip }
  normalizes :notes, with: ->(value) { value.to_s.strip.presence }

  validates :label, presence: true, length: { maximum: LABEL_LIMIT }
  validates :notes, length: { maximum: NOTES_LIMIT }, allow_nil: true
  validates :position, numericality: { only_integer: true, greater_than: 0 }
  validate :context_shape

  def arrangement_wide?
    arrangement_item_id.nil?
  end

  private

  def context_shape
    return if arrangement_item_id.present?
    return if service_occurrence_id.nil? && supplier_resource_id.nil?

    errors.add(:base, "Arrangement-wide costs cannot select an occurrence or resource")
  end
end
