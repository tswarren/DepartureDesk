# frozen_string_literal: true

# Records an evidenced capacity increase and an explicit deposit for that increase.
# It does not rewrite an earlier deposit requirement and does not infer a rate.
class RecordCruiseSameTermsCapacityIncrease < AgencyCommand
  include ArrangementCommandSupport

  COMMAND_NAME = "record_cruise_same_terms_capacity_increase"

  def initialize(
    agency:, actor:, arrangement:, pool_id:, quantity:, rate_minor_units:,
    evidence:, idempotency_key:, effective_on: nil
  )
    @agency = agency
    @actor = actor
    @arrangement = arrangement
    @pool_id = pool_id
    @quantity = quantity
    @rate_minor_units = rate_minor_units
    @evidence = evidence.to_h.with_indifferent_access
    @idempotency_key = idempotency_key
    @effective_on = effective_on
  end

  def call
    ensure_arrangement_actor!
    quantity = Integer(@quantity, exception: false)
    rate = Integer(@rate_minor_units, exception: false)
    if quantity.nil? || quantity <= 0 || rate.nil? || rate.negative?
      raise Error.new("Enter a positive cabin quantity and a per-cabin deposit rate.", code: :invalid)
    end

    ActiveRecord::Base.transaction do
      lock_authorized_arrangement_agency!
      arrangement = @agency.supplier_arrangements.find(@arrangement.id)
      version = arrangement.versions.lock.find_by!(status: "activated")
      pool = version.capacity_pool_definitions.find_by!(capacity_pool_id: @pool_id).capacity_pool
      projection = pool.capacity_projection
      raise Error.new("Capacity projection is missing.", code: :invalid_state) unless projection

      original_deposit_ids = version.supplier_deposit_requirement_definitions.pluck(:id, :lock_version)
      payload = {
        supplier_arrangement_version_id: version.id,
        capacity_pool_id: pool.id,
        quantity: quantity,
        rate_minor_units: rate,
        evidence: @evidence,
        effective_on: @effective_on&.to_s
      }
      if (replay = replay!(payload))
        return replay
      end

      event_result = IncreaseCapacity.new(
        agency: @agency,
        actor: @actor,
        pool: pool,
        quantity: quantity,
        projection_lock_version: projection.lock_version,
        idempotency_key: "#{normalize_idempotency_key(@idempotency_key)}-capacity",
        effective_on: @effective_on,
        attributes: {
          evidence_kind: @evidence[:evidence_kind],
          evidence_on: @evidence[:evidence_on],
          evidence_reference_note: @evidence[:evidence_reference_note]
        }
      ).call
      requirement = SupplierArrangementCruiseCapacityDepositRequirement.create!(
        agency: @agency,
        departure: arrangement.departure,
        supplier_arrangement: arrangement,
        supplier_arrangement_version: version,
        capacity_pool: pool,
        capacity_event: event_result.record,
        quantity: quantity,
        rate_minor_units: rate,
        amount_minor_units: quantity * rate,
        currency: arrangement.departure.operating_currency
      )
      unchanged = version.supplier_deposit_requirement_definitions.pluck(:id, :lock_version)
      unless unchanged == original_deposit_ids
        raise Error.new("A same-terms increase cannot rewrite an existing deposit requirement.", code: :invalid_state)
      end

      audit!(
        agency: @agency,
        action: "supplier_arrangement.capacity_event_recorded",
        subject: arrangement,
        actor: @actor,
        details: {
          "supplier_arrangement_id" => arrangement.id,
          "supplier_arrangement_version_id" => version.id,
          "capacity_event_id" => event_result.record.id,
          "cruise_capacity_deposit_requirement_id" => requirement.id,
          "quantity" => quantity,
          "rate_minor_units" => rate,
          "amount_minor_units" => requirement.amount_minor_units
        }
      )
      claim!(payload, requirement)
      Result.new(status: :created, record: requirement)
    end
  end

  private

  def replay!(payload)
    key = normalize_idempotency_key(@idempotency_key)
    digest = payload_digest(payload)
    lock_idempotency_slot!(COMMAND_NAME, key)
    existing = AgencyCommandIdempotencyKey.where(
      agency: @agency, command_name: COMMAND_NAME, idempotency_key: key
    ).lock.first
    return nil unless existing
    unless existing.payload_digest == digest
      raise Error.new("That idempotency key was already used for different input.", code: :conflict)
    end

    Result.new(
      status: :replayed,
      record: SupplierArrangementCruiseCapacityDepositRequirement.find(existing.result_record_id)
    )
  end

  def claim!(payload, record)
    AgencyCommandIdempotencyKey.create!(
      agency: @agency,
      command_name: COMMAND_NAME,
      idempotency_key: normalize_idempotency_key(@idempotency_key),
      payload_digest: payload_digest(payload),
      result_record_type: SupplierArrangementCruiseCapacityDepositRequirement.name,
      result_record_id: record.id
    )
  rescue ActiveRecord::RecordNotUnique
    raise Error.new("That idempotency key was already used for different input.", code: :conflict)
  end
end
