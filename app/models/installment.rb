# One installment of a client charge (CMN-08): an amount, a due date and an
# expected route, made at confirmation and never edited (CMN-03, CMN-12).
# What is paid and open is derived from its applications.
class Installment < ApplicationRecord
  belongs_to :agency
  belongs_to :client_charge, inverse_of: :installments
  has_many :applications, class_name: "ClientPaymentApplication", inverse_of: :installment, dependent: :restrict_with_exception

  def paid_minor_units(route = nil)
    rows = applications.to_a
    rows = rows.select { |row| row.client_payment.route == route } if route
    rows.sum(&:amount_minor_units)
  end

  def open_minor_units = amount_minor_units - paid_minor_units
  def paid? = open_minor_units <= 0

  before_update { raise ActiveRecord::ReadOnlyRecord }
  before_destroy { raise ActiveRecord::ReadOnlyRecord }
end
