class MarkCostDefinitionForecastReady < AgencyCommand
  include CostCommandSupport

  def initialize(agency:, actor:, definition:, lock_version:, readiness_provenance: nil)
    @agency, @actor, @definition, @lock_version = agency, actor, definition, lock_version
    @provenance = readiness_provenance
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
        provenance = normalize_text(
          @provenance, "Readiness provenance", SupplierCostDefinition::READINESS_PROVENANCE_LIMIT,
          required: definition.contracted?
        )
        validate_ready!(definition)
        fingerprint = definition_fingerprint(definition)
        if definition.forecast_ready? &&
            definition.readiness_fingerprint == fingerprint &&
            definition.readiness_provenance == provenance
          return Result.new(status: :replayed, record: definition)
        end
        ensure_current_lock_version!(definition, @lock_version)
        definition.update!(
          status: "forecast_ready", forecast_ready_by: @actor, forecast_ready_at: Time.current,
          readiness_provenance: provenance, readiness_fingerprint: fingerprint
        )
        audit_cost!("supplier_arrangement.cost_definition_forecast_ready", arrangement, version, {
          "supplier_cost_source_id" => source.id, "supplier_cost_definition_id" => definition.id,
          "stage" => definition.stage, "mode" => definition.mode, "status" => definition.status,
          "readiness_provenance" => provenance, "readiness_fingerprint" => fingerprint,
          "forecast_ready_by_id" => @actor.id
        })
        Result.new(status: :updated, record: definition)
      end
    end
  end
end
