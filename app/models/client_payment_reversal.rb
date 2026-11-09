# A client payment's reversal, with its reason (CMN-27). Both records are kept.
class ClientPaymentReversal < ApplicationRecord
  REASON_LIMIT = 500

  belongs_to :agency
  belongs_to :client_payment, inverse_of: :reversal
  belongs_to :recorded_by, class_name: "AgencyUser"

  before_update { raise ActiveRecord::ReadOnlyRecord }
  before_destroy { raise ActiveRecord::ReadOnlyRecord }
end
