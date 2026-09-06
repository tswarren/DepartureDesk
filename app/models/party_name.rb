class PartyName
  PersonNames = Data.define(:display_name, :sort_name)

  def self.person(given_name:, family_name:, preferred_name: nil, middle_name: nil, **)
    given = given_name.to_s.strip
    family = family_name.to_s.strip
    preferred = preferred_name.to_s.strip.presence
    middle = middle_name.to_s.strip.presence

    display = if preferred
      "#{preferred} #{family}".squish
    else
      [ given, middle, family ].compact.join(" ").squish
    end

    sort = [ family, [ given, middle ].compact.join(" ").presence ].compact.join(", ")

    PersonNames.new(display_name: display, sort_name: sort)
  end

  def self.household(name:, **)
    value = name.to_s.strip
    PersonNames.new(display_name: value, sort_name: value)
  end

  def self.organization(legal_name:, trading_name: nil, **)
    trading = trading_name.to_s.strip.presence
    legal = legal_name.to_s.strip
    value = trading || legal
    PersonNames.new(display_name: value, sort_name: value)
  end

  def self.normalize(value)
    value.to_s.unicode_normalize(:nfkc).strip.downcase.gsub(/\s+/, " ")
  end
end
