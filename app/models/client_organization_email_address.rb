class ClientOrganizationEmailAddress < ApplicationRecord
  include ClientOrganizationContactPoint

  normalizes :address, with: ->(value) { value.to_s.strip }

  validates :address, presence: true
end
