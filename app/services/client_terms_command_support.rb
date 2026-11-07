# Shared steps for client terms commands (BKG-28, BKG-31, CMN-09). Lock
# order: agency, Departure, then the terms version. A locked version is
# never changed (the database refuses it too).
module ClientTermsCommandSupport
  include OfferingCommandSupport

  TIER_FIELDS = %w[min_days_before_departure charge_kind percentage amount service_category].freeze

  private

  def lock_terms_version!(departure)
    departure.client_terms_versions.lock.find(@terms_version.id).tap do |version|
      raise AgencyCommand::Error.new("These terms are locked: a booking has accepted them.", code: :invalid_state) if version.locked?
    end
  end

  # Assigns a tier's days and charge from staff input (BKG-31).
  def assign_tier!(tier, attributes, currency)
    days = Integer(attributes["min_days_before_departure"].to_s, exception: false)
    raise AgencyCommand::Error.new("Days before departure must be a whole number of 0 or more.", code: :invalid) if days.nil? || days.negative?

    kind = attributes["charge_kind"]
    raise AgencyCommand::Error.new("Choose how the tier charges.", code: :invalid) unless CancellationTier::CHARGE_KINDS.include?(kind)

    tier.assign_attributes(min_days_before_departure: days, charge_kind: kind, percentage: nil, amount_minor_units: nil, currency: nil, service_category: nil)
    if kind == "percentage"
      tier.percentage = parse_percentage(attributes["percentage"])
    else
      tier.amount_minor_units = parse_amount(attributes["amount"], currency)
      tier.currency = currency
      tier.service_category = attributes["service_category"] if kind == "fixed_per_unit"
    end
  end

  def parse_percentage(value)
    text = value.to_s.delete_suffix("%").strip
    unless text.match?(SupplierMoneyCommandSupport::PERCENTAGE_FORMAT) && BigDecimal(text).positive? && BigDecimal(text) <= 100
      raise AgencyCommand::Error.new("Percentage must be more than 0 and at most 100, with up to four decimal places.", code: :invalid)
    end
    BigDecimal(text)
  end

  def parse_amount(value, currency)
    MoneyInput.minor_units(value, currency) or raise AgencyCommand::Error.new("Amount is required.", code: :invalid)
  rescue MoneyInput::Invalid
    raise AgencyCommand::Error.new("Amount must be an amount in #{currency}, such as 1234.50.", code: :invalid)
  end
end
