# frozen_string_literal: true

class SupplierOperatingThresholdDefinition < ApplicationRecord
  include ExactVersionCopyLineage
  include DraftVersionDefinition
  include ActivityConfirmationFreeze::Model

  THRESHOLD_KINDS = %w[minimum_enrollment].freeze
  QUANTITY_BASES = %w[persons].freeze
  AUTHORITIES = %w[supplier_decision].freeze

  belongs_to :agency
  belongs_to :departure
  belongs_to :supplier_arrangement
  belongs_to :supplier_arrangement_version
  belongs_to :arrangement_item
  belongs_to :service_occurrence, optional: true

  enum :threshold_kind, THRESHOLD_KINDS.index_by(&:itself), validate: true
  enum :quantity_basis, QUANTITY_BASES.index_by(&:itself), validate: true
  enum :below_threshold_authority, AUTHORITIES.index_by(&:itself), validate: true

  attr_readonly :agency_id, :departure_id, :supplier_arrangement_id,
    :supplier_arrangement_version_id, :arrangement_item_id, :copied_from_id

  validates :minimum_quantity, numericality: { only_integer: true, greater_than: 0 }
  validates :position, numericality: { only_integer: true, greater_than: 0 }
end
