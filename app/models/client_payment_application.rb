# Part of a client payment applied to an installment (CMN-21). A reversal
# adds a negative application; nothing is edited (CMN-27).
class ClientPaymentApplication < ApplicationRecord
  belongs_to :agency
  belongs_to :client_payment, inverse_of: :applications
  belongs_to :installment, inverse_of: :applications
  belongs_to :recorded_by, class_name: "AgencyUser"

  before_update { raise ActiveRecord::ReadOnlyRecord }
  before_destroy { raise ActiveRecord::ReadOnlyRecord }
end
