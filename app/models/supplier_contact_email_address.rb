class SupplierContactEmailAddress < ApplicationRecord
  include SupplierContactOwnedDestination

  normalizes :address, with: ->(value) { value.to_s.strip.presence }

  validates :address, presence: true
end
