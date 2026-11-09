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
  has_many :installments, -> { order(:position) }, inverse_of: :client_charge, dependent: :restrict_with_exception

  def total_minor_units = lines.sum(&:amount_minor_units)

  # CMN-28: the total, what reached the agency, what reached suppliers, and what remains.
  def paid_minor_units(route = nil) = installments.sum { |installment| installment.paid_minor_units(route) }
  def remainder_minor_units = total_minor_units - paid_minor_units

  before_update { raise ActiveRecord::ReadOnlyRecord }
  before_destroy { raise ActiveRecord::ReadOnlyRecord }
end
