class SupplierWebsite < ApplicationRecord
  include SupplierContactPoint

  validates :url, :normalized_url, :normalized_host, presence: true
end
