class ClientPersonEmailAddress < ApplicationRecord
  include ClientPersonContactPoint

  normalizes :address, with: ->(value) { value.to_s.strip.presence }

  validates :address, presence: true
end
