# frozen_string_literal: true

class SupplierDepositRequirementDefinitionContributorLink < ApplicationRecord
  include DraftVersionDefinition

  belongs_to :agency
  belongs_to :departure
  belongs_to :supplier_arrangement
  belongs_to :supplier_arrangement_version
  belongs_to :supplier_deposit_requirement_definition
  belongs_to :contributor_definition, class_name: "SupplierDepositRequirementDefinition"

  attr_readonly :agency_id, :departure_id, :supplier_arrangement_id,
    :supplier_arrangement_version_id, :supplier_deposit_requirement_definition_id,
    :contributor_definition_id

  validates :position, numericality: { only_integer: true, greater_than: 0 }
  validate :contributor_not_self

  private

  def contributor_not_self
    return if contributor_definition_id.blank? ||
      contributor_definition_id != supplier_deposit_requirement_definition_id

    errors.add(:contributor_definition_id, "can't be the same definition")
  end
end
