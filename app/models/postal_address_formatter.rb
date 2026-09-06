class PostalAddressFormatter
  def self.format(attention: nil, address_line_1:, address_line_2: nil, address_line_3: nil,
    locality: nil, administrative_region: nil, postal_code: nil, country_code:)
    locality_line = [
      locality,
      administrative_region,
      postal_code
    ].map { |part| part.to_s.strip.presence }.compact.join(" ")

    [
      attention,
      address_line_1,
      address_line_2,
      address_line_3,
      locality_line,
      CountryReference.name_for(country_code)
    ].map { |part| part.to_s.strip.presence }.compact.join("\n")
  end

  def self.normalize(formatted)
    formatted.to_s.unicode_normalize(:nfkc).strip.downcase.gsub(/\s+/, " ")
  end
end
