# frozen_string_literal: true

# Pre-satisfaction adjustment appends components that change the open tranche current amount.
# Post-satisfaction positive increments create a new tranche and commitment.
class AdjustSupplierDepositRequirementTranche < AgencyCommand
  include ArrangementCommandSupport

  def initialize(agency:, actor:, tranche:, amount_delta_minor_units:, note:,
    idempotency_key:)
    @agency = agency
    @actor = actor
    @tranche = tranche
    @amount_delta_minor_units = amount_delta_minor_units
    @note = note.to_s.strip.presence
    @idempotency_key = idempotency_key
  end

  def call
    ensure_arrangement_actor!
    delta = Integer(@amount_delta_minor_units)
    raise Error.new("Enter a non-zero amount adjustment.", code: :invalid) if delta.zero?

    ActiveRecord::Base.transaction do
      lock_authorized_arrangement_agency!
      tranche_row = SupplierDepositRequirementTranche.find_by!(id: @tranche.id, agency_id: @agency.id)
      arrangement_row = @agency.supplier_arrangements.find(tranche_row.supplier_arrangement_id)
      lock_suppliers_in_uuid_order!(arrangement_row.contracting_supplier_id)
      lock_departure_for!(arrangement_row.departure_id)
      arrangement = lock_arrangement_for!(arrangement_row)
      raise Error.new("That supplier arrangement has ended.", code: :invalid_state) if arrangement.ended?

      tranche = arrangement.supplier_deposit_requirement_tranches.lock.find(tranche_row.id)
      commitment = SupplierCommitment.lock.find_by!(
        supplier_deposit_requirement_tranche_id: tranche.id
      )

      payload = {
        supplier_deposit_requirement_tranche_id: tranche.id,
        amount_delta_minor_units: delta,
        note: @note
      }

      if commitment.open_state?
        adjust_open_tranche!(arrangement, tranche, commitment, delta, payload)
      else
        raise Error.new(
          "Post-satisfaction positive increments require a positive delta.", code: :invalid
        ) if delta.negative?

        create_increment_tranche!(arrangement, tranche, delta, payload)
      end
    end
  rescue ArgumentError, TypeError
    raise Error.new("Enter a whole-number amount adjustment.", code: :invalid)
  rescue ActiveRecord::RecordInvalid => error
    raise Error.new(error.record.errors.full_messages.to_sentence.presence || error.message, code: :invalid)
  end

  private

  def adjust_open_tranche!(arrangement, tranche, commitment, delta, payload)
    idempotent_create!(
      command_name: "#{self.class.name}#open",
      idempotency_key: @idempotency_key,
      payload:,
      result_class: SupplierDepositRequirementTrancheComponent
    ) do
      now = Time.current
      new_amount = tranche.current_amount_minor_units + delta
      raise Error.new("Deposit amount cannot be negative.", code: :invalid) if new_amount.negative?

      kind = delta.positive? ? "adjustment_increase" : "adjustment_decrease"
      component = SupplierDepositRequirementTrancheComponent.create!(
        agency_id: tranche.agency_id,
        departure_id: tranche.departure_id,
        supplier_arrangement_id: tranche.supplier_arrangement_id,
        supplier_arrangement_version_id: tranche.supplier_arrangement_version_id,
        supplier_deposit_requirement_tranche: tranche,
        component_kind: kind,
        amount_delta_minor_units: delta,
        calculation_snapshot: {
          "prior_amount_minor_units" => tranche.current_amount_minor_units,
          "new_amount_minor_units" => new_amount
        },
        note: @note,
        actor: @actor,
        recorded_at: now
      )
      tranche.apply_current_amount!(amount_minor_units: new_amount)
      component
    end
  end

  def create_increment_tranche!(arrangement, prior_tranche, delta, payload)
    idempotent_create!(
      command_name: "#{self.class.name}#increment",
      idempotency_key: @idempotency_key,
      payload:,
      result_class: SupplierDepositRequirementTranche
    ) do
      now = Time.current
      key = "increment:#{prior_tranche.id}:#{@idempotency_key}"
      tranche = SupplierDepositRequirementTranche.create!(
        agency_id: prior_tranche.agency_id,
        departure_id: prior_tranche.departure_id,
        supplier_arrangement_id: prior_tranche.supplier_arrangement_id,
        supplier_arrangement_version_id: prior_tranche.supplier_arrangement_version_id,
        supplier_deposit_requirement_definition_id: prior_tranche.supplier_deposit_requirement_definition_id,
        supplier_arrangement_activation_id: prior_tranche.supplier_arrangement_activation_id,
        amount_shape: prior_tranche.amount_shape,
        amount_inputs_snapshot: prior_tranche.amount_inputs_snapshot.merge(
          "post_satisfaction_increment" => delta
        ),
        coverage_snapshot: prior_tranche.coverage_snapshot,
        initial_amount_minor_units: delta,
        current_amount_minor_units: delta,
        currency: prior_tranche.currency,
        materialization_key: key,
        predecessor_tranche: prior_tranche,
        governing_deadline_occurrence: prior_tranche.governing_deadline_occurrence,
        actor: @actor,
        materialized_at: now
      )
      SupplierDepositRequirementTrancheComponent.create!(
        agency_id: tranche.agency_id,
        departure_id: tranche.departure_id,
        supplier_arrangement_id: tranche.supplier_arrangement_id,
        supplier_arrangement_version_id: tranche.supplier_arrangement_version_id,
        supplier_deposit_requirement_tranche: tranche,
        component_kind: "post_satisfaction_increment",
        amount_delta_minor_units: delta,
        calculation_snapshot: { "prior_tranche_id" => prior_tranche.id },
        note: @note,
        actor: @actor,
        recorded_at: now
      )
      OpenSupplierDepositCommitmentAlreadyLocked.new(
        tranche:, actor: @actor,
        contracting_supplier_id: arrangement.contracting_supplier_id,
        activation: prior_tranche.supplier_arrangement_activation
      ).call
      tranche
    end
  end
end
