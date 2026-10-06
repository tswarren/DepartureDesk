# frozen_string_literal: true

class MarkCruiseSupplierRateScheduleContractReviewed < AgencyCommand
  include CostCommandSupport
  include CruiseSupplierRateBuilders

  def initialize(agency:, actor:, arrangement:, resource:, definition_lock_version:,
    contract_review_provenance:, stage: "contracted")
    @agency = agency
    @actor = actor
    @arrangement = arrangement
    @resource = resource
    @definition_lock_version = definition_lock_version
    @contract_review_provenance = contract_review_provenance
    @stage = stage
  end

  def call
    ensure_arrangement_actor!
    safely_command do
      shape = DetectCruiseSupplierRateShape.new(
        agency: @agency, arrangement: @arrangement, resource: @resource, stage: @stage
      ).call
      unless shape.compatible? && shape.definition&.contracted?
        raise Error.new("Review the contracted Supplier rates for this cabin.", code: :invalid_state)
      end

      definition = shape.definition
      charges = definition.supplier_cost_components.select { |component| component.economic_role == "supplier_charge" }
      if charges.empty?
        raise Error.new("Add at least one Supplier charge before reviewing contracted terms.", code: :invalid)
      end

      ActiveRecord::Base.transaction do
        lock_authorized_arrangement_agency!
        departure, arrangement, version, contractor = cost_graph!(definition)
        source = lock_source!(version, definition.supplier_cost_source)
        charging = locked_supplier!(source.charging_supplier_id)
        ensure_cost_ordinary_edit!(departure, arrangement, version, contractor, charging)
        definition = lock_definition!(source, definition)
        provenance = normalize_text(
          @contract_review_provenance, "Contract review provenance",
          SupplierCostDefinition::READINESS_PROVENANCE_LIMIT
        )
        validate_ready!(definition, require_usage: false)
        fingerprint = definition_fingerprint(definition)
        if definition.contract_review_current? && definition.contract_review_provenance == provenance
          return Result.new(status: :replayed, record: definition)
        end

        ensure_current_lock_version!(definition, @definition_lock_version)
        definition.update!(
          contract_reviewed_by: @actor,
          contract_reviewed_at: Time.current,
          contract_review_provenance: provenance,
          contract_review_fingerprint: fingerprint
        )
        audit_cost!("supplier_arrangement.cost_definition_contract_reviewed", arrangement, version, {
          "supplier_cost_source_id" => source.id,
          "supplier_cost_definition_id" => definition.id,
          "stage" => definition.stage,
          "contract_review_provenance" => provenance,
          "contract_review_fingerprint" => fingerprint,
          "contract_reviewed_by_id" => @actor.id
        })
        Result.new(status: :updated, record: definition)
      end
    end
  end
end
