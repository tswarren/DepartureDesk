class PhoneNumberNormalizer
  VERSION = 1
  Result = Data.define(:display_number, :normalized_digits, :e164_number, :parsed_country_code, :parse_status)

  class Error < StandardError; end

  def self.normalize(raw, default_country: nil)
    display = raw.to_s.strip
    raise Error, "Enter a phone number." if display.blank?

    digits = display.gsub(/\D/, "")
    raise Error, "Enter a phone number that includes digits." if digits.blank?

    parsed = parse(display, default_country)

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

  def self.format(display_number:, e164_number: nil, parsed_country_code: nil, extension: nil, home_country: nil)
    number = formatted_base(
      display_number:,
      e164_number:,
      parsed_country_code:,
      home_country:
    )
    ext = extension.to_s.strip.presence
    ext ? "#{number} ext. #{ext}" : number
  end

  def self.formatted_base(display_number:, e164_number: nil, parsed_country_code: nil, home_country: nil)
    fallback = display_number.to_s.strip
    parsed = parse_for_format(
      display_number: fallback,
      e164_number:,
      parsed_country_code:,
      home_country:
    )
    return fallback if parsed.blank? || (!parsed.valid? && !parsed.possible?)

    home = home_country.to_s.strip.upcase.presence
    formatted = if home.present? && parsed.country.to_s.upcase == home
      parsed.national
    else
      parsed.international
    end
    formatted.presence || fallback
  end
  private_class_method :formatted_base

  def self.parse_for_format(display_number:, e164_number:, parsed_country_code:, home_country:)
    if e164_number.to_s.strip.present?
      parse(e164_number)
    else
      parse(display_number, parsed_country_code.presence || home_country)
    end
  end
  private_class_method :parse_for_format

  def self.parse(value, default_country = nil)
    if default_country.present?
      Phonelib.parse(value, default_country)
    else
      Phonelib.parse(value)
    end
  end
  private_class_method :parse
end
