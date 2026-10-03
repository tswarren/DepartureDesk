# frozen_string_literal: true

class SupplierPaymentRequirementDefinition < ApplicationRecord
  include ExactVersionCopyLineage
  include DraftVersionDefinition
  include ActivityConfirmationFreeze::Model

  KINDS = %w[full_payment].freeze
  QUANTITY_STATUSES = %w[authoritative_quantity_unavailable].freeze

  belongs_to :agency
  belongs_to :departure
  belongs_to :supplier_arrangement
  belongs_to :supplier_arrangement_version
  belongs_to :arrangement_item
  belongs_to :supplier_cost_component

  enum :kind, KINDS.index_by(&:itself), validate: true
  enum :quantity_status, QUANTITY_STATUSES.index_by(&:itself), validate: true

  attr_readonly :agency_id, :departure_id, :supplier_arrangement_id,
    :supplier_arrangement_version_id, :arrangement_item_id, :kind, :copied_from_id

  normalizes :currency, with: ->(value) { value.to_s.strip.upcase }

  validates :currency, presence: true, format: { with: Agency::CURRENCY_FORMAT }
  validates :due_on, presence: true
  validates :position, numericality: { only_integer: true, greater_than: 0 }
  validate :component_is_per_person_rate

  private

  def component_is_per_person_rate
    component = supplier_cost_component
    return if component.nil?
    return if component.unit_rate? && component.persons? && component.quantity_capacity_pool_id.nil?

    errors.add(:supplier_cost_component, "must be the per-person Supplier rate")
  end
end
