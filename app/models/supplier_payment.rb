# A payment the agency made to a supplier (SMN-18): supplier, payee account
# if known, date, amount, method and references, with an SPY- reference.
# Applied to that supplier's amounts due on the Departure (SMN-19); what
# isn't applied stays as an unapplied supplier payment (SMN-22). Never
# edited: a reversal corrects it (SMN-23). A payment never changes cost or
# capacity (SMN-03, D-92).
class SupplierPayment < ApplicationRecord
  METHODS = %w[bank_transfer card check cash other].freeze
  METHOD_LABELS = { "bank_transfer" => "Bank transfer", "card" => "Card", "check" => "Check", "cash" => "Cash", "other" => "Other" }.freeze
  REFERENCE_LIMIT = 120

  belongs_to :agency
  belongs_to :departure
  belongs_to :supplier
  belongs_to :payee_account, optional: true
  belongs_to :recorded_by, class_name: "AgencyUser"
  has_many :applications, class_name: "SupplierPaymentApplication", inverse_of: :supplier_payment, dependent: :restrict_with_exception
  has_one :reversal, class_name: "SupplierPaymentReversal", inverse_of: :supplier_payment, dependent: :restrict_with_exception

  validates :payment_method, inclusion: { in: METHODS }

  def reversed? = reversal.present?
  def method_label = METHOD_LABELS.fetch(payment_method)
  def applied_minor_units = applications.sum(&:amount_minor_units)
  def unapplied_minor_units = reversed? ? 0 : amount_minor_units - applied_minor_units

  before_update { raise ActiveRecord::ReadOnlyRecord }
  before_destroy { raise ActiveRecord::ReadOnlyRecord }
end
