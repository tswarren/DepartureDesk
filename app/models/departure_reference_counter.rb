class DepartureReferenceCounter < ApplicationRecord
  self.primary_key = "agency_id"

  belongs_to :agency

  validates :last_value, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end
