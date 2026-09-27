# frozen_string_literal: true

class SupplierArrangementCommercialBenefit < ApplicationRecord
  belongs_to :agency
  belongs_to :departure
  belongs_to :supplier_arrangement

  has_many :definitions,
    class_name: "SupplierArrangementCommercialBenefitDefinition",
    dependent: :restrict_with_exception

  attr_readonly :agency_id, :departure_id, :supplier_arrangement_id
end
