class CountryReference
  def self.options
    seen_codes = {}
    seen_labels = {}

    ISO3166::Country.all
      .sort_by { |country| [ country.iso_short_name, country.alpha2 ] }
      .each_with_object([]) do |country, rows|
        name = country.iso_short_name
        code = country.alpha2
        next if name.blank? || code.blank? || seen_codes[code] || seen_labels[name]

        seen_codes[code] = true
        seen_labels[name] = true
        rows << [ name, code ]
      end
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
