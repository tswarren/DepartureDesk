# A confirmed booking's one client charge (CMN-01), made at confirmation
# from the accepted price snapshot together with the accepted terms
# (BKG-25, D-94). Its lines are never edited (CMN-03). Installments,
# payments and receipts arrive in build step 8.
class ClientCharge < ApplicationRecord
  belongs_to :agency
  belongs_to :client_booking
  belongs_to :client_terms_version
  belongs_to :booking_acceptance
  has_many :lines, class_name: "ChargeLine", inverse_of: :client_charge, dependent: :restrict_with_exception

  def total_minor_units = lines.sum(&:amount_minor_units)

  before_update { raise ActiveRecord::ReadOnlyRecord }
  before_destroy { raise ActiveRecord::ReadOnlyRecord }
end
