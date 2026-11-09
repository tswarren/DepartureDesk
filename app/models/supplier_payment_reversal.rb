# A supplier payment's reversal, with its reason (SMN-23). Both records are kept.
class SupplierPaymentReversal < ApplicationRecord
  REASON_LIMIT = 500

  belongs_to :agency
  belongs_to :supplier_payment, inverse_of: :reversal
  belongs_to :recorded_by, class_name: "AgencyUser"

  before_update { raise ActiveRecord::ReadOnlyRecord }
  before_destroy { raise ActiveRecord::ReadOnlyRecord }
end
