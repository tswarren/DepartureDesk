class SupplierPostalAddress < ApplicationRecord
  include SupplierContactPoint

  normalizes :line_1, :line_2, :locality, :region, :postal_code, with: ->(value) { value.to_s.strip.presence }
  normalizes :country_code, with: ->(value) { value.to_s.strip.upcase.presence }

  validates :line_1, :country_code, presence: true
end
