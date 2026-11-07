# Commission the agency expects from a supplier for one booking service
# (SMN-32), proposed from the arrangement's rate table at booking
# confirmation (SUP-35, D-75, D-92). Staff with Supplier arrangements or
# Financial records may override it while it is Expected. Later statuses
# (SMN-33) arrive with supplier money and reconciliation.
class ExpectedCommission < ApplicationRecord
  belongs_to :agency
  belongs_to :supplier_arrangement
  belongs_to :client_booking
  belongs_to :choice_selection
  belongs_to :overridden_by, class_name: "AgencyUser", optional: true

  def overridden? = overridden_at.present?
end
