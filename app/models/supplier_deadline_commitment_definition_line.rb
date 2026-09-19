# frozen_string_literal: true

class SupplierDeadlineCommitmentDefinitionLine < ApplicationRecord
  include DraftVersionDefinition

  AUTHORITY_SHAPES = %w[fixed_quantity fixed_contracted_amount].freeze
  QUANTITY_BASES = %w[resource_units traveler_positions].freeze
  DESCRIPTION_LIMIT = 500

  belongs_to :agency
  belongs_to :departure
  belongs_to :supplier_arrangement
  belongs_to :supplier_arrangement_version
  belongs_to :supplier_deadline_definition
  belongs_to :committed_supplier, class_name: "Supplier"
  belongs_to :supplier_cost_source, optional: true
  belongs_to :supplier_cost_definition, optional: true
  belongs_to :supplier_cost_component, optional: true
  belongs_to :copied_from, class_name: "SupplierDeadlineCommitmentDefinitionLine", optional: true

  enum :authority_shape, AUTHORITY_SHAPES.index_by(&:itself), validate: true
  enum :quantity_basis, QUANTITY_BASES.index_by(&:itself), validate: { allow_nil: true }

  attr_readonly :agency_id, :departure_id, :supplier_arrangement_id,
    :supplier_arrangement_version_id, :supplier_deadline_definition_id, :copied_from_id

  normalizes :description, with: ->(value) { value.to_s.strip }
  normalizes :currency, with: ->(value) { value.to_s.strip.upcase.presence }

  validates :description, presence: true, length: { maximum: DESCRIPTION_LIMIT }
  validates :position, numericality: { only_integer: true, greater_than: 0 }
  validates :fixed_quantity, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validate :authority_fields_match_shape

  private

  def authority_fields_match_shape
    expected = case authority_shape
    when "fixed_quantity"
      fixed_quantity.present? && quantity_basis.present? && monetary_fields_blank?
    when "fixed_contracted_amount"
      fixed_quantity.nil? && quantity_basis.nil? && currency.present? &&
        supplier_cost_definition_id.present? && supplier_cost_component_id.present?
    end
    errors.add(:base, "Authority fields do not match the selected shape") unless expected
  end

  def monetary_fields_blank?
    currency.nil? && supplier_cost_definition_id.nil? && supplier_cost_component_id.nil?
  end
end
