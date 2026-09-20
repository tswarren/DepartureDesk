class CapacityPool < ApplicationRecord
  INVENTORY_MODES = %w[block allotment on_request externally_managed].freeze
  MEASUREMENT_BASES = %w[resource_units traveler_positions].freeze

  belongs_to :agency
  belongs_to :departure
  belongs_to :supplier_arrangement
  belongs_to :arrangement_item
  belongs_to :service_occurrence
  belongs_to :supplier_resource
  belongs_to :supplying_supplier, class_name: "Supplier"

  has_many :definitions, class_name: "CapacityPoolDefinition", dependent: :restrict_with_exception
  has_many :capacity_events, dependent: :restrict_with_exception
  has_one :capacity_projection, dependent: :restrict_with_exception
  has_many :capacity_reconciliations, dependent: :restrict_with_exception
  has_many :service_offer_source_bindings, dependent: :restrict_with_exception

  enum :inventory_mode, INVENTORY_MODES.index_by(&:itself), validate: true
  enum :measurement_basis, MEASUREMENT_BASES.index_by(&:itself), validate: true

  attr_readonly :agency_id, :departure_id, :supplier_arrangement_id,
    :arrangement_item_id, :service_occurrence_id, :supplier_resource_id,
    :supplying_supplier_id, :inventory_mode, :measurement_basis, :effective_time_zone

  normalizes :effective_time_zone, with: ->(value) { value.to_s.strip.presence }

  validates :effective_time_zone, presence: true
  validate :timezone_is_iana

  def numeric_inventory?
    block? || allotment?
  end

  private

  def timezone_is_iana
    return if effective_time_zone.blank?

    TZInfo::Timezone.get(effective_time_zone)
  rescue TZInfo::InvalidTimezoneIdentifier
    errors.add(:effective_time_zone, "is not a recognized IANA timezone")
  end
end
