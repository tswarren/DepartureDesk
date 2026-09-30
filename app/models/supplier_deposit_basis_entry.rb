# frozen_string_literal: true

class SupplierDepositBasisEntry < ApplicationRecord
  include ExactVersionCopyLineage
  include DraftVersionDefinition

  belongs_to :agency
  belongs_to :departure
  belongs_to :supplier_arrangement
  belongs_to :supplier_arrangement_version
  belongs_to :supplier_deposit_basis
  belongs_to :arrangement_item
  belongs_to :service_occurrence
  belongs_to :supplier_resource

  attr_readonly :agency_id, :departure_id, :supplier_arrangement_id,
    :supplier_arrangement_version_id, :supplier_deposit_basis_id, :arrangement_item_id,
    :service_occurrence_id, :supplier_resource_id

  validates :agreed_quantity, numericality: { only_integer: true, greater_than: 0 }
  validates :agreed_unit_rate_minor_units, :extended_amount_minor_units,
    numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :extension_matches_quantity_and_rate

  private

  def extension_matches_quantity_and_rate
    return if agreed_quantity.nil? || agreed_unit_rate_minor_units.nil? || extended_amount_minor_units.nil?
    return if agreed_quantity * agreed_unit_rate_minor_units == extended_amount_minor_units

    errors.add(:extended_amount_minor_units, "must equal quantity times rate")
  end
end
