class PhoneNumberNormalizer
  VERSION = 1
  Result = Data.define(:display_number, :normalized_digits, :e164_number, :parsed_country_code, :parse_status)

  class Error < StandardError; end

  def self.normalize(raw, default_country: nil)
    display = raw.to_s.strip
    raise Error, "Enter a phone number." if display.blank?

    digits = display.gsub(/\D/, "")
    raise Error, "Enter a phone number that includes digits." if digits.blank?

    parsed = if default_country.present?
      Phonelib.parse(display, default_country)
    else
      Phonelib.parse(display)
    end

    parse_status = if parsed.valid?
      "valid"
    elsif parsed.possible?
      "possible"
    else
      "unparsed"
    end

    Result.new(
      display_number: display,
      normalized_digits: digits,
      e164_number: (parsed.full_e164.presence if parsed.valid?),
      parsed_country_code: parsed.country.presence,
      parse_status:
    )
  end
end
