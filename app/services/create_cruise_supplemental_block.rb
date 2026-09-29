# frozen_string_literal: true

# Opens a successor and a second cabin block for a selected active category.
# When no category is selected, the block stays Supplier code O1.
# The successor stays unconfirmed, without contracted rates or a deposit treatment.
class CreateCruiseSupplementalBlock < AgencyCommand
  include ArrangementCommandSupport

  LABEL = "Supplemental O1 block"
  SUPPLIER_CODE = "O1"
  ResultRecord = Data.define(:version, :resource, :pool)

  def initialize(
    agency:, actor:, arrangement:, arrangement_lock_version:, version_lock_version:,
    idempotency_key:, maximum_occupancy:, opening_quantity:, supplier_resource_id: nil
  )
    @agency = agency
    @actor = actor
    @arrangement = arrangement
    @arrangement_lock_version = arrangement_lock_version
    @version_lock_version = version_lock_version
    @idempotency_key = idempotency_key
    @maximum_occupancy = maximum_occupancy
    @opening_quantity = opening_quantity
    @supplier_resource_id = supplier_resource_id
  end

  def call
    ensure_arrangement_actor!
    occupancy = Integer(@maximum_occupancy, exception: false)
    quantity = Integer(@opening_quantity, exception: false)
    if occupancy.nil? || occupancy <= 0 || quantity.nil? || quantity <= 0
      raise Error.new("Enter the supplemental occupancy and opening quantity.", code: :invalid)
    end

    ActiveRecord::Base.transaction do
      lock_authorized_arrangement_agency!
      arrangement = @agency.supplier_arrangements.find(@arrangement.id)
      code, name = supplemental_identity(arrangement)
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
          name: name,
          supplier_code: code,
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

  private

  def supplemental_identity(arrangement)
    return [ SUPPLIER_CODE, LABEL ] if @supplier_resource_id.blank?

    predecessor = arrangement.versions.find_by!(id: arrangement.governing_version_id)
    unless predecessor.activated?
      raise Error.new("The governing Supplier terms are not active.", code: :invalid_state)
    end

    definition = predecessor.supplier_resource_definitions.find_by(supplier_resource_id: @supplier_resource_id)
    unless definition
      raise Error.new("Choose a cabin category on the active version.", code: :not_found)
    end

    code = definition.supplier_code.to_s.strip
    if code.blank?
      raise Error.new("That cabin category has no Supplier code.", code: :invalid)
    end

    [ code, "Supplemental #{code} block" ]
  end
end
