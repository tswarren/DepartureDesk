# A cancellation tier's stored values as staff typed them, for refilling
# its form.
module TierFormValues
  def self.for(tier)
    {
      "min_days_before_departure" => tier.min_days_before_departure, "percentage" => tier.percentage&.to_s("F"),
      "amount" => tier.amount_minor_units && MoneyInput.display(tier.amount_minor_units, tier.currency), "service_category" => tier.service_category
    }
  end
end
