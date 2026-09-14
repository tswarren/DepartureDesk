class CountryCode
  REJECTED = %w[XX ZZ].freeze
  SHAPE = /\A[A-Z]{2}\z/

  def self.accepted?(value)
    code = value.to_s.strip.upcase
    return false unless SHAPE.match?(code)
    return false if REJECTED.include?(code)

    ISO3166::Country[code].present?
  end

  def self.normalize(value)
    code = value.to_s.strip.upcase
    accepted?(code) ? code : nil
  end

  def self.options
    ISO3166::Country.all.filter_map do |country|
      code = country.alpha2
      next unless accepted?(code)

      [ "#{country.iso_short_name} (#{code})", code ]
    end.sort_by(&:first)
  end
end
