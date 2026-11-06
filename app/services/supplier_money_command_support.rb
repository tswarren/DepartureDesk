# Shared parsing for cost and schedule line commands. Money is parsed
# strictly in the arrangement currency (ADR 0001).
module SupplierMoneyCommandSupport
  PERCENTAGE_FORMAT = /\A\d{1,3}(?:\.\d{1,4})?\z/

  private

  def ensure_open_arrangement!(arrangement)
    return if arrangement.draft? || arrangement.confirmed?

    raise AgencyCommand::Error.new("Only a draft or confirmed arrangement's supplier cost can change.", code: :invalid_state)
  end

  def parse_money!(field, label, currency, required: false)
    value = MoneyInput.minor_units(@attributes[field], currency)
    raise AgencyCommand::Error.new("#{label} is required.", code: :invalid) if required && value.nil?

    value
  rescue MoneyInput::Invalid
    raise AgencyCommand::Error.new("#{label} must be an amount in #{currency}, such as 1234.50.", code: :invalid)
  end

  def parse_percentage!(field)
    value = @attributes[field].to_s.delete_suffix("%").strip
    unless value.match?(PERCENTAGE_FORMAT) && BigDecimal(value).positive? && BigDecimal(value) <= 100
      raise AgencyCommand::Error.new("Percentage must be more than 0 and at most 100, with up to four decimal places.", code: :invalid)
    end
    BigDecimal(value)
  end

  def parse_count!(field, label, minimum: 1)
    value = Integer(@attributes[field].to_s, exception: false)
    raise AgencyCommand::Error.new("#{label} must be a whole number of at least #{minimum}.", code: :invalid) if value.nil? || value < minimum

    value
  end

  def find_in!(relation, field, label)
    return nil if @attributes[field].blank?

    relation.find_by(id: parse_optional_uuid(@attributes[field], label)) or
      raise AgencyCommand::Error.new("Choose one of this arrangement's #{label.downcase.pluralize}.", code: :invalid)
  end
end
