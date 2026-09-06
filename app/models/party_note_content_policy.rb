class PartyNoteContentPolicy
  PAN_DIGITS = (13..19)
  SECRET_ASSIGNMENT = /
    (?:password|passwd|secret|api[_-]?key|private[_-]?key|access[_-]?token|auth[_-]?token)
    \s*[:=]\s*\S+
  /ix
  KEY_MARKER = /-----BEGIN (?:RSA |OPENSSH |EC |DSA )?PRIVATE KEY-----/

  def self.violation_for(body)
    text = body.to_s
    return "Notes cannot include payment-card numbers." if luhn_pan?(text)
    return "Notes cannot include private keys or credential files." if text.match?(KEY_MARKER)
    return "Notes cannot include passwords, tokens, or access secrets." if text.match?(SECRET_ASSIGNMENT)

    nil
  end

  def self.allowed?(body)
    violation_for(body).blank?
  end

  def self.luhn_pan?(text)
    candidates(text).any? { |digits| PAN_DIGITS.cover?(digits.length) && luhn_valid?(digits) }
  end

  def self.candidates(text)
    text.scan(/(?:\d[ \-]?){13,19}\d/).map { |value| value.gsub(/\D/, "") }
  end
  private_class_method :candidates

  def self.luhn_valid?(digits)
    sum = digits.reverse.chars.each_with_index.sum do |char, index|
      n = char.to_i
      n *= 2 if index.odd?
      n > 9 ? n - 9 : n
    end
    sum.modulo(10).zero?
  end
  private_class_method :luhn_valid?
end
