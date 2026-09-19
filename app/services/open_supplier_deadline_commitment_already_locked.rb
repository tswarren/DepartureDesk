# frozen_string_literal: true

class OpenSupplierDeadlineCommitmentAlreadyLocked
  def initialize(occurrence:, line:, actor:, activation: nil)
    @occurrence = occurrence
    @line = line
    @actor = actor
    @activation = activation
  end

  def call
    existing = SupplierCommitment.find_by(
      supplier_deadline_occurrence_id: @occurrence.id,
      supplier_deadline_commitment_definition_line_id: @line.id
    )
    return existing if existing

    quantity, amount = authoritative_values
    SupplierCommitment.create!(
      agency_id: @occurrence.agency_id,
      departure_id: @occurrence.departure_id,
      supplier_arrangement_id: @occurrence.supplier_arrangement_id,
      supplier_arrangement_version_id: @occurrence.supplier_arrangement_version_id,
      supplier_arrangement_activation: @activation,
      opening_kind: "deadline_requirement",
      supplier_deadline_occurrence: @occurrence,
      supplier_deadline_commitment_definition_line: @line,
      committed_supplier_id: @line.committed_supplier_id,
      commitment_type: quantity ? "quantity" : "monetary",
      description: @line.description,
      quantity:,
      quantity_basis: quantity && @line.quantity_basis,
      amount_minor_units: amount,
      currency: amount && @line.currency,
      calculation_snapshot: calculation_snapshot(quantity, amount),
      actor: @actor,
      opened_at: Time.current
    )
  rescue ActiveRecord::RecordNotUnique
    SupplierCommitment.find_by!(
      supplier_deadline_occurrence_id: @occurrence.id,
      supplier_deadline_commitment_definition_line_id: @line.id
    )
  end

  private

  def authoritative_values
    case @line.authority_shape
    when "fixed_quantity"
      [ @line.fixed_quantity, nil ]
    when "fixed_contracted_amount"
      definition = @line.supplier_cost_definition
      component = @line.supplier_cost_component
      unless definition&.contracted? && definition.forecast_ready? &&
          component&.supplier_charge? && component.fixed? &&
          definition.currency == @line.currency
        raise AgencyCommand::Error.new(
          "The contracted monetary authority is no longer complete.", code: :invalid
        )
      end
      [ nil, component.amount_minor_units ]
    else
      raise AgencyCommand::Error.new("Deadline commitment authority is incomplete.", code: :invalid)
    end
  end

  def calculation_snapshot(quantity, amount)
    [
      "opening_kind=deadline_requirement",
      "authority=#{@line.authority_shape}",
      ("quantity=#{quantity}" if quantity),
      ("amount_minor_units=#{amount}" if amount),
      ("line_id=#{@line.id}"),
      ("occurrence_id=#{@occurrence.id}")
    ].compact.join(";")
  end
end
