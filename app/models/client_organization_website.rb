class ClientOrganizationWebsite < ApplicationRecord
  include ClientOrganizationContactPoint

  validates :url, :normalized_url, :normalized_host, presence: true
end
