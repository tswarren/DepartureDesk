# One tier of a Departure's override of the agency cancellation tiers
# (BKG-31). Fixed once its terms version is locked.
class ClientCancellationTier < ApplicationRecord
  include CancellationTier

  belongs_to :agency
  belongs_to :client_terms_version

  attr_readonly :agency_id, :client_terms_version_id
end
