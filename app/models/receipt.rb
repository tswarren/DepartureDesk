# An agency receipt (CMN-55): issued with an agency-route payment, numbered
# without gaps (REF-05), for one Departure. It snapshots what the payment
# was and what it was applied to at issue; later applications show on the
# payment, and a reversal beside the receipt, never on it. Immutable.
class Receipt < ApplicationRecord
  belongs_to :agency
  belongs_to :client_payment, inverse_of: :receipt
  belongs_to :departure
  has_many :document_versions, -> { order(:issued_at) }, inverse_of: :receipt, dependent: :restrict_with_exception

  before_update { raise ActiveRecord::ReadOnlyRecord }
  before_destroy { raise ActiveRecord::ReadOnlyRecord }
end
