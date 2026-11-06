# One of the agency's default client cancellation tiers (BKG-31). A
# Departure's terms follow these unless they override them.
class AgencyCancellationTier < ApplicationRecord
  include CancellationTier

  belongs_to :agency

  attr_readonly :agency_id
end
