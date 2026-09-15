class SupplierPhoneNumber < ApplicationRecord
  include SupplierContactPoint

  validates :number, :normalized_number, :country_code, presence: true
end
