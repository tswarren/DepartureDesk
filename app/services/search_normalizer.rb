class SearchNormalizer
  def self.normalize(value)
    return "" if value.blank?

    ApplicationRecord.connection.select_value(
      "SELECT dd_search_normalize(#{ApplicationRecord.connection.quote(value)})"
    ).to_s
  end

  def self.tokens(value)
    normalize(value).split(" ").reject(&:blank?)
  end
end
