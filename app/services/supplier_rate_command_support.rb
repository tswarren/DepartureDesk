# Shared by the supplier rate grid commands (S-14, SUP-35): the table and
# its pattern change only while the arrangement is a draft (ADR 0018), and
# amounts are parsed strictly in the arrangement's currency (ADR 0001).
module SupplierRateCommandSupport
  include ArrangementCommandSupport

  RATE_FORMAT = /\A\d{1,3}(?:\.\d{1,3})?\z/

  private

  def lock_draft_arrangement!
    departure = lock_arrangement_context!
    arrangement = lock_arrangement!(departure)
    raise AgencyCommand::Error.new("The rate table can change only while the arrangement is a draft.", code: :invalid_state) unless arrangement.draft?

    arrangement
  end

  def parse_money(value, currency, label)
    MoneyInput.minor_units(value, currency)
  rescue MoneyInput::Invalid
    raise AgencyCommand::Error.new("#{label} must be an amount in #{currency}, such as 1234.50.", code: :invalid)
  end

  def parse_commission_rate(value, label)
    text = value.to_s.delete_suffix("%").strip
    return nil if text.empty?
    unless text.match?(RATE_FORMAT) && BigDecimal(text) <= 100
      raise AgencyCommand::Error.new("#{label} must be a percentage from 0 to 100, with up to three decimal places.", code: :invalid)
    end

    BigDecimal(text)
  end

  # { method:, rate:, base:, amount: } from typed commission fields.
  def parse_commission(values, currency, label)
    method = values["commission_method"].presence || "percent"
    case method
    when "percent"
      base = values["commission_base"].presence || "base_fare"
      raise AgencyCommand::Error.new("#{label}: choose what the commission rate applies to.", code: :invalid) unless base.in?(SupplierRateLine::COMMISSION_BASES)

      { method:, rate: parse_commission_rate(values["commission_rate"], "#{label} commission rate"), base:, amount: nil }
    when "amount"
      amount = parse_money(values["commission_amount"], currency, "#{label} commission amount")
      raise AgencyCommand::Error.new("#{label} commission amount is required for a dollar commission.", code: :invalid) if amount.nil?

      { method:, rate: nil, base: nil, amount: }
    else
      raise AgencyCommand::Error.new("#{label}: choose a percentage or a dollar amount.", code: :invalid)
    end
  end

  # A typed traveler type may share positions with the untyped bands only;
  # bands for the same type never overlap.
  def ensure_no_overlap!(arrangement, positions, traveler_type_id, except: nil)
    clash = arrangement.rate_bands.reject { |band| band.id == except }.find do |band|
      band.traveler_type_id == traveler_type_id && (band.positions & positions).any?
    end
    return unless clash

    raise AgencyCommand::Error.new("Positions overlap the #{clash.label} band for the same travelers; each guest needs exactly one fare.", code: :invalid)
  end

  def replace_bands!(arrangement, definitions)
    arrangement.rate_lines.where.not(supplier_rate_band_id: nil).update_all(supplier_rate_band_id: nil)
    arrangement.rate_bands.reload.each(&:destroy!)
    definitions.each_with_index do |definition, index|
      arrangement.rate_bands.create!(agency: @agency, label: definition[:label], positions: definition[:positions],
        traveler_type_id: definition[:traveler_type_id], position: index)
    end
    arrangement.rate_bands.reset
  end
end
