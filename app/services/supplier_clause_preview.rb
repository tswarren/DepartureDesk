class SupplierClausePreview
  CapacityConsequence = Data.define(:event_type, :resource_id, :service_occurrence_id, :capacity_unit, :quantity, :deltas)
  CommitmentConsequence = Data.define(:action, :commitment_id, :governing_term_id, :amount_minor_units, :currency)

  attr_reader :clause, :capacity_consequence, :commitment_consequence

  def initialize(clause:, capacity_consequence: nil, commitment_consequence: nil)
    @clause = clause
    @capacity_consequence = capacity_consequence
    @commitment_consequence = commitment_consequence
  end

  def capacity?
    capacity_consequence.present?
  end

  def commitment?
    commitment_consequence.present?
  end
end
