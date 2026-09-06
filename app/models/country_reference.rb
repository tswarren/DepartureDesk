class CountryReference
  def self.options
    ISO3166::Country.all.map { |country| [ country.iso_short_name, country.alpha2 ] }.sort_by(&:first)
  end

  def self.valid_code?(code)
    ISO3166::Country[code.to_s.strip.upcase].present?
  end

  def self.name_for(code)
    ISO3166::Country[code.to_s.strip.upcase]&.iso_short_name.presence || code.to_s
  end

  def self.subdivision_options(code)
    country = ISO3166::Country[code.to_s.strip.upcase]
    return [] unless country

    country.subdivisions.map { |_iso, subdivision| [ subdivision.name, subdivision.name ] }.sort_by(&:first)
  end
end
