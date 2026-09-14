class ClientOrganizationPhoneNumber < ApplicationRecord
  include ClientOrganizationContactPoint

  validates :number, :normalized_number, :country_code, presence: true
end
