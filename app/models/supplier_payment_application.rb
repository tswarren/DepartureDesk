# Part of a supplier payment applied to an amount due (SMN-19). A reversal
# adds a negative application; nothing is edited (SMN-23).
class SupplierPaymentApplication < ApplicationRecord
  belongs_to :agency
  belongs_to :supplier_payment, inverse_of: :applications
  belongs_to :amount_due, inverse_of: :payment_applications
  belongs_to :recorded_by, class_name: "AgencyUser"

  before_update { raise ActiveRecord::ReadOnlyRecord }
  before_destroy { raise ActiveRecord::ReadOnlyRecord }
end
