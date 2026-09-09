class SupplierCostTermEvaluation
  Result = Data.define(:amount_minor_units, :currency, :quantity, :explanation)

  def self.evaluate(term, resource_quantity: nil, person_quantity: nil, night_count: nil, qualifying_quantity: nil, base_amount_minor_units: nil)
    new(term, resource_quantity:, person_quantity:, night_count:, qualifying_quantity:, base_amount_minor_units:).evaluate
  end

  def initialize(term, resource_quantity: nil, person_quantity: nil, night_count: nil, qualifying_quantity: nil, base_amount_minor_units: nil)
    @term = term
    @resource_quantity = resource_quantity
    @person_quantity = person_quantity
    @night_count = night_count
    @qualifying_quantity = qualifying_quantity
    @base_amount_minor_units = base_amount_minor_units
  end

  def evaluate
    case @term.shape
    when "fixed" then fixed
    when "per_resource" then per_resource
    when "per_person" then per_person
    when "per_night" then per_night
    when "minimum_guarantee" then minimum_guarantee
    when "tiered" then tiered
    when "stepped" then stepped
    when "percentage" then percentage
    when "complimentary_ratio" then complimentary_ratio
    when "pass_through" then pass_through
    when "manual_estimate" then manual_estimate
    else
      raise ArgumentError, "Unknown supplier cost term shape"
    end
  end

  private

  def fixed
    detail = required_detail(:fixed_detail)
    result(detail.amount_minor_units, 1, "fixed amount")
  end

  def per_resource
    detail = required_detail(:per_resource_detail)
    quantity = positive_integer(@resource_quantity || input("resource_quantity") || 1, "resource quantity")
    result(detail.unit_amount_minor_units * quantity, quantity, "unit amount multiplied by resource quantity")
  end

  def per_person
    detail = required_detail(:per_person_detail)
    quantity = positive_integer(@person_quantity || detail.person_quantity, "person quantity")
    result(detail.unit_amount_minor_units * quantity, quantity, "unit amount multiplied by explicit planning or guaranteed person quantity")
  end

  def per_night
    detail = required_detail(:per_night_detail)
    quantity = positive_integer(@night_count || input("night_count") || occurrence_count, "night count")
    result(detail.unit_amount_minor_units * quantity, quantity, "unit amount multiplied by qualifying night count")
  end

  def minimum_guarantee
    detail = required_detail(:minimum_guarantee_detail)
    quantity_amount = if detail.minimum_quantity && detail.unit_amount_minor_units
      detail.minimum_quantity * detail.unit_amount_minor_units
    end
    amount = [ detail.minimum_amount_minor_units, quantity_amount ].compact.max
    quantity = detail.minimum_quantity || 1
    result(amount, quantity, "minimum guarantee amount")
  end

  def manual_estimate
    detail = required_detail(:manual_estimate_detail)
    result(detail.forecast_amount_minor_units, 1, "manual estimate: #{detail.reason}")
  end

  def tiered
    quantity = qualifying_quantity
    tier = @term.tiers.select { |candidate| candidate.threshold_quantity <= quantity }.max_by(&:threshold_quantity)
    raise ArgumentError, "No tier qualifies for quantity" unless tier

    result(tier.unit_amount_minor_units * quantity, quantity, "tiered rate selected at #{tier.threshold_quantity} #{@term.quantity_unit}")
  end

  def stepped
    quantity = qualifying_quantity
    amount = @term.steps.sum do |step|
      next 0 if quantity < step.band_start_quantity

      band_end = step.band_end_quantity || quantity
      units = [ quantity, band_end ].min - step.band_start_quantity + 1
      units.positive? ? units * step.unit_amount_minor_units : 0
    end
    result(amount, quantity, "stepped rates applied across qualifying bands")
  end

  def percentage
    detail = required_detail(:percentage_base_ref)
    base_amount = percentage_base_amount(detail)
    amount = round_basis_points(base_amount, detail.rate_basis_points)

    result(amount, 1, "percentage #{detail.rate_basis_points} basis points of #{detail.base_reference}")
  end

  def complimentary_ratio
    quantity = qualifying_quantity
    rule = @term.complimentary_ratio_rules.select { |candidate| candidate.minimum_qualifying_quantity <= quantity }.max_by(&:minimum_qualifying_quantity)
    raise ArgumentError, "No complimentary ratio rule qualifies for quantity" unless rule

    complimentary_quantity = complimentary_quantity_for(rule, quantity)
    paid_quantity = quantity - complimentary_quantity
    result(paid_quantity * rule.unit_amount_minor_units, paid_quantity, "complimentary ratio charged #{paid_quantity} of #{quantity} #{@term.quantity_unit}")
  end

  def pass_through
    detail = required_detail(:pass_through_provenance)
    result(detail.supplier_amount_minor_units, 1, "pass-through supplier amount: #{detail.supplier_amount_reference}")
  end

  def required_detail(name)
    @term.public_send(name) || raise(ArgumentError, "Missing detail for #{@term.shape} supplier cost term")
  end

  def input(key)
    @term.evaluation_inputs.fetch(key, nil)
  end

  def occurrence_count
    @term.service_occurrence_id.present? ? 1 : nil
  end

  def qualifying_quantity
    positive_integer(@qualifying_quantity || input("qualifying_quantity") || input("quantity"), "qualifying quantity")
  end

  def positive_integer(value, label)
    integer = Integer(value)
    raise ArgumentError, "#{label} must be positive" unless integer.positive?

    integer
  rescue TypeError, ArgumentError
    raise ArgumentError, "#{label} must be positive"
  end

  def result(amount, quantity, explanation)
    Result.new(amount_minor_units: amount, currency: @term.currency, quantity:, explanation:)
  end

  def percentage_base_amount(detail)
    amount = @base_amount_minor_units || detail.base_amount_minor_units || input("base_amount_minor_units")
    return nonnegative_integer(amount, "base amount") if amount.present?

    if detail.base_economic_item_key.present? || detail.base_economic_item_id.present?
      valuation = percentage_base_valuation(detail)
      raise ArgumentError, "Referenced percentage base must use #{@term.currency}" unless valuation.currency == @term.currency

      return nonnegative_integer(valuation.amount_minor_units, "base amount")
    end

    raise ArgumentError, "Percentage cost terms require a base amount"
  end

  def nonnegative_integer(value, label)
    integer = Integer(value)
    raise ArgumentError, "#{label} must be nonnegative" if integer.negative?

    integer
  rescue TypeError, ArgumentError
    raise ArgumentError, "#{label} must be nonnegative"
  end

  def round_basis_points(amount_minor_units, rate_basis_points)
    (amount_minor_units * rate_basis_points + 5_000) / 10_000
  end

  def percentage_base_valuation(detail)
    controlling = if detail.base_economic_item_key.present?
      SupplierEconomicItemPrecedence.controlling_for(agency: @term.agency, economic_item_key: detail.base_economic_item_key)
    else
      controlling_by_economic_item_id(detail.base_economic_item_id)
    end
    raise ArgumentError, "Referenced percentage base does not have an active valuation" unless controlling

    controlling.valuation
  end

  def controlling_by_economic_item_id(economic_item_id)
    if (commitment = SupplierCommitment.open.where(agency: @term.agency, economic_item_id:).order(:created_at).last)
      return SupplierEconomicItemPrecedence::Result.new(
        stage: "commitment",
        record: commitment,
        valuation: Result.new(
          amount_minor_units: commitment.valuation_amount_minor_units,
          currency: commitment.currency,
          quantity: commitment.valuation_details["quantity"],
          explanation: "open commitment valuation"
        )
      )
    end

    if (term = SupplierCostTerm.active.where(agency: @term.agency, economic_item_id:, basis: "contracted").order(:term_version).last)
      return SupplierEconomicItemPrecedence::Result.new(stage: "contracted", record: term, valuation: self.class.evaluate(term))
    end

    if (term = SupplierCostTerm.active.where(agency: @term.agency, economic_item_id:, basis: "estimate").order(:term_version).last)
      return SupplierEconomicItemPrecedence::Result.new(stage: "estimate", record: term, valuation: self.class.evaluate(term))
    end
  end

  def complimentary_quantity_for(rule, quantity)
    cycle_quantity = rule.paid_unit_quantity + rule.complimentary_unit_quantity
    cycles = case rule.rounding_rule
    when "floor" then quantity / cycle_quantity
    when "ceiling" then (quantity + cycle_quantity - 1) / cycle_quantity
    when "nearest" then (quantity * 2 + cycle_quantity) / (cycle_quantity * 2)
    else
      raise ArgumentError, "Unknown complimentary rounding rule"
    end
    [ cycles * rule.complimentary_unit_quantity, quantity ].min
  end
end
