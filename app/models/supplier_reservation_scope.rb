class SupplierReservationScope < ApplicationRecord
  TARGET_KINDS = %w[arrangement item occurrence resource capacity_pool].freeze
  QUANTITY_BASES = %w[resource_units traveler_positions].freeze
  LABEL_LIMIT = 160

  belongs_to :agency
  belongs_to :departure
  belongs_to :supplier_arrangement
  belongs_to :supplier_arrangement_version
  belongs_to :supplier_reservation
  belongs_to :supplier_reservation_revision
  belongs_to :arrangement_item, optional: true
  belongs_to :service_occurrence, optional: true
  belongs_to :supplier_resource, optional: true
  belongs_to :capacity_pool, optional: true

  has_many :outcomes, class_name: "SupplierReservationEventScopeOutcome",
    dependent: :restrict_with_exception

  enum :target_kind, TARGET_KINDS.index_by(&:itself), validate: true
  enum :quantity_basis, QUANTITY_BASES.index_by(&:itself), validate: { allow_nil: true }

  attr_readonly :agency_id, :departure_id, :supplier_arrangement_id,
    :supplier_arrangement_version_id, :supplier_reservation_id,
    :supplier_reservation_revision_id

  normalizes :label, with: ->(value) { value.to_s.strip.presence }

  validates :position, numericality: { only_integer: true, greater_than: 0 }
  validates :label, length: { maximum: LABEL_LIMIT }, allow_nil: true
  validates :requested_quantity, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validate :target_shape
  validate :quantity_shape

  private

  def target_shape
    expected = case target_kind
    when "arrangement"
      [ arrangement_item_id, service_occurrence_id, supplier_resource_id, capacity_pool_id ].all?(&:nil?)
    when "item"
      arrangement_item_id.present? && service_occurrence_id.nil? &&
        supplier_resource_id.nil? && capacity_pool_id.nil?
    when "occurrence"
      arrangement_item_id.present? && service_occurrence_id.present? &&
        supplier_resource_id.nil? && capacity_pool_id.nil?
    when "resource"
      arrangement_item_id.present? && service_occurrence_id.nil? &&
        supplier_resource_id.present? && capacity_pool_id.nil?
    when "capacity_pool"
      arrangement_item_id.present? && service_occurrence_id.present? &&
        supplier_resource_id.present? && capacity_pool_id.present?
    end
    errors.add(:base, "Reservation scope target does not match target kind") unless expected
  end

  def quantity_shape
    errors.add(:quantity_basis, "must be present with quantity") if requested_quantity.present? && quantity_basis.blank?
    errors.add(:quantity_basis, "must be blank without quantity") if requested_quantity.blank? && quantity_basis.present?
  end
end
