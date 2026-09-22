# frozen_string_literal: true

class MarkCruiseSupplierRateScheduleForecastReady < AgencyCommand
  include CostCommandSupport
  include CruiseSupplierRateBuilders

  def initialize(agency:, actor:, arrangement:, resource:, definition_lock_version:,
    readiness_provenance: nil, confirm_omissions: false)
    @agency = agency
    @actor = actor
    @arrangement = arrangement
    @resource = resource
    @definition_lock_version = definition_lock_version
    @readiness_provenance = readiness_provenance
    @confirm_omissions = confirm_omissions
  end

  def call
    ensure_arrangement_actor!
    safely_command do
      unless ActiveModel::Type::Boolean.new.cast(@confirm_omissions)
        raise Error.new(
          "Confirm that blank Supplier terms are not applicable and omitted commission means no expected commission.",
          code: :invalid
        )
      end

      shape = DetectCruiseSupplierRateShape.new(
        agency: @agency, arrangement: @arrangement, resource: @resource
      ).call
      unless shape.compatible? && shape.definition
        raise Error.new("These Supplier terms need advanced cost planning.", code: :invalid_state)
      end

      definition = shape.definition
      charges = definition.supplier_cost_components.select { |c| c.economic_role == "supplier_charge" }
      if charges.empty?
        raise Error.new("Add at least one Supplier charge before marking terms forecast-ready.", code: :invalid)
      end

      MarkCostDefinitionForecastReady.new(
        agency: @agency,
        actor: @actor,
        definition: definition,
        lock_version: @definition_lock_version,
        readiness_provenance: @readiness_provenance
      ).call
    end
  end
end
