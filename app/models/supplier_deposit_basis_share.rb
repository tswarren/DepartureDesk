# frozen_string_literal: true

class SupplierDepositBasisShare < ApplicationRecord
  include ExactVersionCopyLineage
  include DraftVersionDefinition

  belongs_to :agency
  belongs_to :departure
  belongs_to :supplier_arrangement
  belongs_to :supplier_arrangement_version
  belongs_to :supplier_deposit_basis
  belongs_to :arrangement_item
  belongs_to :supplier_deposit_requirement_definition

  attr_readonly :agency_id, :departure_id, :supplier_arrangement_id,
    :supplier_arrangement_version_id, :supplier_deposit_basis_id, :arrangement_item_id,
    :supplier_deposit_requirement_definition_id

  validates :share_basis_points, numericality: {
    only_integer: true, greater_than: 0, less_than_or_equal_to: 10_000
  }
  validates :supplier_deposit_requirement_definition_id, uniqueness: true
end
