# Parses a staff-entered amount into minor units of a currency (ADR 0001).
# Accepts "1234", "1,234.50" or "1234.5"; refuses a sign, a symbol, or more
# decimal places than the currency has, rather than rounding.
module MoneyInput
  FORMAT = /\A(?:\d{1,3}(?:,\d{3})+|\d+)(?:\.(\d+))?\z/

  class Invalid < StandardError; end

  # Returns nil for a blank entry.
  def self.minor_units(text, currency)
    text = text.to_s.strip
    return nil if text.empty?

    match = FORMAT.match(text) or raise Invalid
    exponent = Money::Currency.new(currency).exponent
    raise Invalid if match[1].to_s.length > exponent

    (BigDecimal(text.delete(",")) * (10**exponent)).to_i
  end

  # Minor units back to the plain form staff type, for refilling a form.
  def self.display(minor_units, currency)
    return "" if minor_units.nil?

    Money.new(minor_units, currency).to_s
  end
end
