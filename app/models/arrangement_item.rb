class ArrangementItem < ApplicationRecord
  belongs_to :agency
  belongs_to :departure
  belongs_to :supplier_arrangement

  has_many :definitions, class_name: "ArrangementItemDefinition", dependent: :restrict_with_exception
  has_many :service_occurrences, dependent: :restrict_with_exception
  has_many :supplier_resources, dependent: :restrict_with_exception

  attr_readonly :agency_id, :departure_id, :supplier_arrangement_id
end
