class EmailAddressNormalizer
  VERSION = 1
  MAX_LENGTH = 254

  class Error < StandardError; end

  def self.normalize(raw)
    display = raw.to_s.strip
    raise Error, "Enter an email address." if display.blank?
    raise Error, "Enter a shorter email address." if display.length > MAX_LENGTH
    raise Error, "Enter an email address without spaces or control characters." if display.match?(/[[:space:][:cntrl:]]/)

    parts = display.split("@", -1)
    unless parts.size == 2 && parts[0].present? && parts[1].present?
      raise Error, "Enter an email address with one @ and both a local and domain part."
    end

    {
      display_address: display,
      normalized_address: display.unicode_normalize(:nfkc).downcase
    }
  end
end
