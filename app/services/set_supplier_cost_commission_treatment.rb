# frozen_string_literal: true

class SetSupplierCostCommissionTreatment < AgencyCommand
  include CostCommandSupport

  def initialize(agency:, actor:, definition:, commission_treatment:, lock_version:)
    @agency = agency
    @actor = actor
    @definition = definition
    @commission_treatment = commission_treatment
    @lock_version = lock_version
  end

  def call
    ensure_arrangement_actor!
    safely_command do
      ActiveRecord::Base.transaction do
        lock_authorized_arrangement_agency!
        departure, arrangement, version, contractor = cost_graph!(@definition)
        source = lock_source!(version, @definition.supplier_cost_source)
        charging = locked_supplier!(source.charging_supplier_id)
        ensure_cost_ordinary_edit!(departure, arrangement, version, contractor, charging)
        definition = lock_definition!(source, @definition)
        ensure_current_lock_version!(definition, @lock_version)
        treatment = normalize_treatment!
        return Result.new(status: :noop, record: definition) if definition.commission_treatment == treatment

        if treatment == "noncommissionable" &&
            definition.supplier_cost_components.exists?(economic_role: "expected_commission")
          raise Error.new(
            "Noncommissionable definitions cannot contain expected commission.",
            code: :invalid_state
          )
        end

        definition.update!(commission_treatment: treatment, **READINESS_FIELDS)
        audit_cost!("supplier_arrangement.cost_definition_commission_treatment_set", arrangement, version, {
          "supplier_cost_source_id" => source.id,
          "supplier_cost_definition_id" => definition.id,
          "commission_treatment" => definition.commission_treatment
        })
        Result.new(status: :updated, record: definition)
      end
    end
  end

  private

  def normalize_treatment!
    treatment = @commission_treatment.to_s.strip
    return treatment if SupplierCostDefinition::COMMISSION_TREATMENTS.include?(treatment)

    raise Error.new("Commission treatment must be unspecified or noncommissionable.", code: :invalid)
  end
end
