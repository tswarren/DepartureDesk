class PhoneNumberNormalizer
  Result = Data.define(:number, :normalized_number, :extension, :country_code)
  E164_SHAPE = /\A\+[1-9][0-9]{0,14}\z/
  EXTENSION_SHAPE = /\A[0-9]{1,10}\z/
  PASTED_EXTENSION = /(?:,|\s)+(?:ext\.?|extension|x)\s*([0-9]{1,10})\s*\z/i

  def self.call(number:, extension: nil, country_code: nil)
    new(number:, extension:, country_code:).call
  end

  def initialize(number:, extension:, country_code:)
    @number = number.to_s.strip
    @extension = extension.to_s.strip.presence
    @country_code = country_code.to_s.strip.upcase.presence
  end

  def call
    display, pasted_extension = extract_pasted_extension
    extension = resolve_extension(pasted_extension)
    country = resolve_country
    parsed = Phonelib.parse(display, country)
    normalized = parsed.e164.to_s
    unless parsed.valid? && parsed.valid_for_country?(country) && E164_SHAPE.match?(normalized)
      raise AgencyCommand::Error.new("Enter a valid telephone number for the selected country.", code: :invalid)
    end

    Result.new(
      number: self.class.national(normalized, country),
      normalized_number: normalized,
      extension: extension,
      country_code: country
    )
  end

  def self.national(normalized_number, country_code)
    parsed = Phonelib.parse(normalized_number, country_code)
    parsed.national.presence || parsed.international.presence || normalized_number
  end

  def self.display(normalized_number:, country_code:, extension: nil, viewer_country: nil)
    parsed = Phonelib.parse(normalized_number, country_code)
    formatted = if viewer_country.present? && country_code.present? && viewer_country.to_s.upcase != country_code.to_s.upcase
      parsed.international.presence
    else
      parsed.national.presence
    end
    text = formatted.presence || parsed.international.presence || normalized_number
    [ text, extension.presence && "ext. #{extension}" ].compact.join(" ")
  end

  private

  def extract_pasted_extension
    return [ @number, nil ] if @extension.present?

    match = @number.match(PASTED_EXTENSION)
    return [ @number, nil ] unless match

    [ @number.sub(PASTED_EXTENSION, "").strip, match[1] ]
  end

  def resolve_extension(pasted_extension)
    if @extension.present? && pasted_extension.present? && @extension != pasted_extension
      raise AgencyCommand::Error.new("The telephone extension conflicts with the number.", code: :invalid)
    end

    extension = @extension || pasted_extension
    return if extension.blank?
    return extension if EXTENSION_SHAPE.match?(extension)

    raise AgencyCommand::Error.new("Enter an extension of at most 10 digits.", code: :invalid)
  end

  def resolve_country
    return @country_code if @country_code.present? && CountryCode.accepted?(@country_code)

    raise AgencyCommand::Error.new("Choose a country for this telephone number.", code: :invalid)
  end
end
