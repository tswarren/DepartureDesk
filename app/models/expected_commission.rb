# Commission the agency expects from a supplier for one booking service
# (SMN-32), proposed from the arrangement's rate table at booking
# confirmation (SUP-35, D-75, D-92). Staff with Supplier arrangements or
# Financial records may override it while it is Expected, and record the
# supplier's confirmation of the amount, after which it can't be overridden
# (SMN-33, D-96 (4)). Received, Offset, Adjusted and Reversed are later.
class ExpectedCommission < ApplicationRecord
  belongs_to :agency
  belongs_to :supplier_arrangement
  belongs_to :client_booking
  belongs_to :choice_selection
  belongs_to :overridden_by, class_name: "AgencyUser", optional: true
  belongs_to :confirmed_by, class_name: "AgencyUser", optional: true

  STATUS_LABELS = { "expected" => "Expected", "confirmed" => "Confirmed" }.freeze

  def confirmed? = status == "confirmed"
  def status_label = STATUS_LABELS.fetch(status)

  def overridden? = overridden_at.present?
end
