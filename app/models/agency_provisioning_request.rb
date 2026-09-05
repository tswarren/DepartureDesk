class AgencyProvisioningRequest < ApplicationRecord
  belongs_to :agency

  validates :idempotency_key_digest, presence: true, uniqueness: true
  validates :intent_digest, presence: true, uniqueness: true
end
