class SupplierCostTermEvaluation
  Result = Data.define(:amount_minor_units, :currency, :quantity, :explanation)

  def self.evaluate(term, resource_quantity: nil, person_quantity: nil, night_count: nil)
    new(term, resource_quantity:, person_quantity:, night_count:).evaluate
  end

  def initialize(term, resource_quantity: nil, person_quantity: nil, night_count: nil)
    @term = term
    @resource_quantity = resource_quantity
    @person_quantity = person_quantity
    @night_count = night_count
  end

  def evaluate
    case @term.shape
    when "fixed" then fixed
    when "per_resource" then per_resource
    when "per_person" then per_person
    when "per_night" then per_night
    when "minimum_guarantee" then minimum_guarantee
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

  def required_detail(name)
    @term.public_send(name) || raise(ArgumentError, "Missing detail for #{@term.shape} supplier cost term")
  end

  def input(key)
    @term.evaluation_inputs.fetch(key, nil)
  end

  def occurrence_count
    @term.service_occurrence_id.present? ? 1 : nil
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
end
