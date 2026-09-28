# frozen_string_literal: true

# Opens a successor and a second cabin block that keeps Supplier code O1.
# The successor stays unconfirmed, without contracted rates or a deposit treatment.
class CreateCruiseSupplementalBlock < AgencyCommand
  include ArrangementCommandSupport

  LABEL = "Supplemental O1 block"
  SUPPLIER_CODE = "O1"
  ResultRecord = Data.define(:version, :resource, :pool)

  def initialize(
    agency:, actor:, arrangement:, arrangement_lock_version:, version_lock_version:,
    idempotency_key:, maximum_occupancy:, opening_quantity:
  )
    @agency = agency
    @actor = actor
    @arrangement = arrangement
    @arrangement_lock_version = arrangement_lock_version
    @version_lock_version = version_lock_version
    @idempotency_key = idempotency_key
    @maximum_occupancy = maximum_occupancy
    @opening_quantity = opening_quantity
  end

  def call
    ensure_arrangement_actor!
    occupancy = Integer(@maximum_occupancy, exception: false)
    quantity = Integer(@opening_quantity, exception: false)
    if occupancy.nil? || occupancy <= 0 || quantity.nil? || quantity <= 0
      raise Error.new("Enter the supplemental occupancy and opening quantity.", code: :invalid)
    end

    ActiveRecord::Base.transaction do
      successor = CreateSupplierArrangementSuccessor.new(
        agency: @agency,
        actor: @actor,
        arrangement: @arrangement,
        arrangement_lock_version: @arrangement_lock_version,
        version_lock_version: @version_lock_version,
        idempotency_key: "#{normalize_idempotency_key(@idempotency_key)}-successor"
      ).call
      version = successor.record.reload
      cabin = CreateCruiseCabinCategorySetup.new(
        agency: @agency,
        actor: @actor,
        arrangement: @arrangement,
        resource_attributes: {
          name: LABEL,
          supplier_code: SUPPLIER_CODE,
          maximum_occupancy: occupancy
        },
        pool_attributes: {
          inventory_mode: "block",
          proposed_opening_quantity: quantity
        },
        version_lock_version: version.lock_version,
        idempotency_key: "#{normalize_idempotency_key(@idempotency_key)}-cabin"
      ).call
      Result.new(
        status: :created,
        record: ResultRecord.new(
          version: version,
          resource: cabin.record.resource,
          pool: cabin.record.pool
        )
      )
    end
  end
end
