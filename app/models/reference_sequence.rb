# One counter per agency and reference type (REF-02, REF-03, REF-05, D-84,
# D-89). FORMATS holds each type's prefix and minimum width. A number past the
# minimum width widens, except the six-digit client and supplier formats,
# which stop at EXHAUSTED_AT. GAPLESS types must be issued in the same
# transaction as their record, under the sequence row lock.
class ReferenceSequence < ApplicationRecord
  CLIENT_NAMESPACE = "client"
  SUPPLIER_NAMESPACE = "supplier"
  DEPARTURE_NAMESPACE = "departure"
  TRIP_NAMESPACE = "trip"
  CLIENT_PAYMENT_NAMESPACE = "client_payment"
  ARRANGEMENT_NAMESPACE = "arrangement"
  SUPPLIER_PAYMENT_NAMESPACE = "supplier_payment"
  CONFIRMATION_NAMESPACE = "confirmation"
  INVOICE_NAMESPACE = "invoice"
  RECEIPT_NAMESPACE = "receipt"

  Format = Data.define(:prefix, :width, :fixed_width)

  FORMATS = {
    CLIENT_NAMESPACE => Format.new(prefix: "CL", width: 6, fixed_width: true),
    SUPPLIER_NAMESPACE => Format.new(prefix: "SUP", width: 6, fixed_width: true),
    DEPARTURE_NAMESPACE => Format.new(prefix: "DEP", width: 4, fixed_width: false),
    TRIP_NAMESPACE => Format.new(prefix: "T", width: 5, fixed_width: false),
    CLIENT_PAYMENT_NAMESPACE => Format.new(prefix: "PAY", width: 5, fixed_width: false),
    ARRANGEMENT_NAMESPACE => Format.new(prefix: "ARR", width: 4, fixed_width: false),
    SUPPLIER_PAYMENT_NAMESPACE => Format.new(prefix: "SPY", width: 4, fixed_width: false),
    CONFIRMATION_NAMESPACE => Format.new(prefix: "CNF", width: 5, fixed_width: false),
    INVOICE_NAMESPACE => Format.new(prefix: "INV", width: 5, fixed_width: false),
    RECEIPT_NAMESPACE => Format.new(prefix: "RCP", width: 5, fixed_width: false)
  }.freeze
  NAMESPACES = FORMATS.keys.freeze
  GAPLESS = [ INVOICE_NAMESPACE, RECEIPT_NAMESPACE ].freeze
  EXHAUSTED_AT = 1_000_000

  belongs_to :agency

  attr_readonly :agency_id, :namespace

  validates :namespace, inclusion: { in: NAMESPACES }
  validates :next_value, numericality: { only_integer: true, greater_than: 0 }
  validates :next_value, numericality: { less_than_or_equal_to: EXHAUSTED_AT }, if: :fixed_width?

  def self.format_reference(namespace, number)
    definition = FORMATS.fetch(namespace)
    "#{definition.prefix}-#{number.to_s.rjust(definition.width, "0")}"
  end

  def self.reference_pattern(namespace)
    definition = FORMATS.fetch(namespace)
    digits = definition.fixed_width ? "{#{definition.width}}" : "{#{definition.width},}"
    /\A#{Regexp.escape(definition.prefix)}-[0-9]#{digits}\z/
  end

  def fixed_width?
    FORMATS[namespace]&.fixed_width
  end
end
