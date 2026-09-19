# frozen_string_literal: true

class OpenSupplierDepositCommitmentAlreadyLocked
  def initialize(tranche:, actor:, contracting_supplier_id:, activation: nil)
    @tranche = tranche
    @actor = actor
    @contracting_supplier_id = contracting_supplier_id
    @activation = activation
  end

  def call
    existing = SupplierCommitment.find_by(
      supplier_deposit_requirement_tranche_id: @tranche.id
    )
    return existing if existing

    amount = @tranche.current_amount_minor_units
    SupplierCommitment.create!(
      agency_id: @tranche.agency_id,
      departure_id: @tranche.departure_id,
      supplier_arrangement_id: @tranche.supplier_arrangement_id,
      supplier_arrangement_version_id: @tranche.supplier_arrangement_version_id,
      supplier_arrangement_activation: @activation,
      opening_kind: "deposit_requirement",
      supplier_deposit_requirement_tranche: @tranche,
      committed_supplier_id: @contracting_supplier_id,
      commitment_type: "monetary",
      description: deposit_description,
      amount_minor_units: amount,
      currency: @tranche.currency,
      calculation_snapshot: calculation_snapshot(amount),
      actor: @actor,
      opened_at: Time.current
    )
  rescue ActiveRecord::RecordNotUnique
    SupplierCommitment.find_by!(supplier_deposit_requirement_tranche_id: @tranche.id)
  end

  private

  def deposit_description
    definition = @tranche.supplier_deposit_requirement_definition
    definition.description.presence || "Deposit requirement (#{definition.amount_shape.humanize})"
  end

  def calculation_snapshot(amount)
    [
      "opening_kind=deposit_requirement",
      "amount_shape=#{@tranche.amount_shape}",
      "amount_minor_units=#{amount}",
      "tranche_id=#{@tranche.id}"
    ].join(";")
  end
end
