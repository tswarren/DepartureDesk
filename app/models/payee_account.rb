# Where a supplier is paid (SUP-02). Supplier payments, credits and
# commission settle against a payee account in later steps.
class PayeeAccount < ApplicationRecord
  NAME_LIMIT = 120
  INSTRUCTIONS_LIMIT = 4_000

  belongs_to :agency
  belongs_to :supplier

  attr_readonly :agency_id, :supplier_id

  normalizes :name, with: ->(value) { value.to_s.squish }
  normalizes :currency, with: ->(value) { value.to_s.strip.upcase }
  normalizes :payment_instructions, with: ->(value) { value.to_s.gsub("\r\n", "\n").strip.presence }

  validates :name, presence: true, length: { maximum: NAME_LIMIT }, uniqueness: { scope: :supplier_id, case_sensitive: false }
  validates :currency, format: { with: Agency::CURRENCY_FORMAT }
  validates :payment_instructions, length: { maximum: INSTRUCTIONS_LIMIT }, allow_nil: true
  validate :currency_is_known
  validate :same_agency

  private

  def currency_is_known
    return if currency.blank?

    Money::Currency.new(currency)
  rescue Money::Currency::UnknownCurrency
    errors.add(:currency, "is not a supported currency")
  end

  def same_agency
    errors.add(:supplier, "must belong to the same agency") if supplier && supplier.agency_id != agency_id
  end
end
