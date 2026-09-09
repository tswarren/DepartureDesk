class SupplierEconomicItemPrecedence
  Result = Data.define(:stage, :record, :valuation)

  def self.controlling_for(agency:, economic_item_key:)
    new(agency:, economic_item_key:).controlling
  end

  def initialize(agency:, economic_item_key:)
    @agency = agency
    @economic_item_key = economic_item_key
  end

  def controlling
    if (commitment = SupplierCommitment.open.where(agency: @agency, economic_item_key: @economic_item_key).order(:created_at).last)
      return Result.new(stage: "commitment", record: commitment, valuation: commitment_valuation(commitment))
    end

    if (term = SupplierCostTerm.active.where(agency: @agency, economic_item_key: @economic_item_key, basis: "contracted").order(:term_version).last)
      return Result.new(stage: "contracted", record: term, valuation: SupplierCostTermEvaluation.evaluate(term))
    end

    if (term = SupplierCostTerm.active.where(agency: @agency, economic_item_key: @economic_item_key, basis: "estimate").order(:term_version).last)
      return Result.new(stage: "estimate", record: term, valuation: SupplierCostTermEvaluation.evaluate(term))
    end

    nil
  end

  private

  def commitment_valuation(commitment)
    SupplierCostTermEvaluation::Result.new(
      amount_minor_units: commitment.valuation_amount_minor_units,
      currency: commitment.currency,
      quantity: commitment.valuation_details["quantity"],
      explanation: "open commitment valuation"
    )
  end
end
