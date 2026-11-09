# A client payment on a Client Trip (CMN-18, CMN-29): who paid, when, how
# much, and whether it reached the agency or a supplier. Only an agency
# payment is agency cash and gets a receipt (CMN-55); a supplier payment on
# an agency-owed line is supplier-held funds due to the agency (SMN-27).
# Never edited: a reversal corrects it (CMN-27). What isn't applied is the
# trip's credit (CMN-23, CMN-24).
class ClientPayment < ApplicationRecord
  ROUTES = %w[agency supplier].freeze
  METHODS = %w[check bank_transfer card cash other].freeze
  METHOD_LABELS = { "check" => "Check", "bank_transfer" => "Bank transfer", "card" => "Card", "cash" => "Cash", "other" => "Other" }.freeze
  REFERENCE_LIMIT = 120

  belongs_to :agency
  belongs_to :client_trip, inverse_of: :client_payments
  belongs_to :payer, class_name: "Client", foreign_key: :payer_client_id
  belongs_to :supplier, optional: true
  belongs_to :recorded_by, class_name: "AgencyUser"
  has_many :applications, class_name: "ClientPaymentApplication", inverse_of: :client_payment, dependent: :restrict_with_exception
  has_one :reversal, class_name: "ClientPaymentReversal", inverse_of: :client_payment, dependent: :restrict_with_exception
  has_one :receipt, inverse_of: :client_payment, dependent: :restrict_with_exception
  has_many :acceptances, class_name: "BookingAcceptance", dependent: :restrict_with_exception

  validates :route, inclusion: { in: ROUTES }
  validates :payment_method, inclusion: { in: METHODS }

  def agency_route? = route == "agency"
  def supplier_route? = route == "supplier"
  def reversed? = reversal.present?
  def method_label = METHOD_LABELS.fetch(payment_method)
  def applied_minor_units = applications.sum(&:amount_minor_units)
  def credit_minor_units = reversed? ? 0 : amount_minor_units - applied_minor_units
  def collector_label = agency_route? ? "the agency" : supplier.display_name_for_directory

  before_update { raise ActiveRecord::ReadOnlyRecord }
  before_destroy { raise ActiveRecord::ReadOnlyRecord }
end
