# frozen_string_literal: true

# Copies an estimate Supplier rate definition onto a contracted sibling.
# The estimate stays unchanged and the copy is not forecast-ready.
class RecordCruiseContractedRates < AgencyCommand
  include ArrangementCommandSupport
  include CostCommandSupport
  include CruiseSupplierRateBuilders

  COMMAND_NAME = "record_cruise_contracted_rates"
  COPY_EXCLUDED = %w[
    id created_at updated_at lock_version copied_from_id supplier_cost_definition_id
  ].freeze

  def initialize(agency:, actor:, arrangement:, resource:, version_lock_version:, idempotency_key:)
    @agency = agency
    @actor = actor
    @arrangement = arrangement
    @resource = resource
    @version_lock_version = version_lock_version
    @idempotency_key = idempotency_key
  end

  def call
    ensure_arrangement_actor!

    ActiveRecord::Base.transaction do
      lock_authorized_arrangement_agency!
      departure, arrangement, version = lock_departure_arrangement_version!(@arrangement)
      ensure_draft_graph!(arrangement, version)
      ensure_departure_accepts_new_planning!(departure)
      _item_definition, _occurrence_definition, resource_definition, item, occurrence, resource =
        resolve_cruise_rate_context!(arrangement, version, @resource.id)
      source = find_exact_context_source(version, item: item, occurrence: occurrence, resource: resource)
      raise Error.new("Record an estimate before copying contracted rates.", code: :invalid_state) unless source

      source = lock_source!(version, source)
      estimate = source.supplier_cost_definitions.lock.find_by(stage: "estimate")
      raise Error.new("Record an estimate before copying contracted rates.", code: :invalid_state) unless estimate

      payload = {
        supplier_arrangement_version_id: version.id,
        supplier_cost_source_id: source.id,
        estimate_definition_id: estimate.id
      }
      if (replay = replay_matching_command!(payload))
        return replay
      end

      ensure_current_lock_version!(version, @version_lock_version)
      if source.supplier_cost_definitions.exists?(stage: "contracted")
        raise Error.new(
          "Contracted rates are already recorded for this cabin category.",
          code: :invalid_state
        )
      end

      contracted = build_supplier_cost_definition_already_locked!(
        source: source,
        arrangement: arrangement,
        attributes: {
          stage: "contracted",
          mode: estimate.mode,
          currency: estimate.currency,
          rounding_mode: estimate.rounding_mode,
          zero_cost_reason: estimate.zero_cost_reason,
          copied_from: estimate
        }
      )
      copy_components!(estimate, contracted)
      estimate_snapshot = estimate.attributes
      estimate.reload
      unless estimate.attributes.except("updated_at", "lock_version") == estimate_snapshot.except("updated_at", "lock_version")
        raise Error.new("Recording contracted rates changed the estimate.", code: :invalid_state)
      end
      unless contracted.working? && contracted.forecast_ready_at.nil?
        raise Error.new("Contracted rates must stay working until Staff marks them ready.", code: :invalid_state)
      end

      bump_version!(version)
      audit_cost!("supplier_arrangement.cost_definition_created", arrangement, version, {
        "supplier_cost_source_id" => source.id,
        "supplier_cost_definition_id" => contracted.id,
        "copied_from_supplier_cost_definition_id" => estimate.id,
        "stage" => "contracted",
        "cruise_contracted_rate_copy" => true,
        "supplier_code" => resource_definition.supplier_code
      })
      claim_command!(payload, contracted)
      Result.new(status: :created, record: contracted)
    end
  end

  private

  def copy_components!(estimate, contracted)
    copies = {}
    estimate.supplier_cost_components.order(:position, :id).each do |component|
      copies[component.id] = contracted.supplier_cost_components.create!(
        component.attributes.except(*COPY_EXCLUDED).merge(
          "copied_from_id" => component.id
        )
      )
    end
    estimate.supplier_cost_components.flat_map(&:supplier_cost_component_bases).each do |base|
      SupplierCostComponentBase.create!(
        base.attributes.except(*COPY_EXCLUDED).merge(
          "supplier_cost_definition_id" => contracted.id,
          "supplier_cost_component_id" => copies.fetch(base.supplier_cost_component_id).id,
          "base_component_id" => copies.fetch(base.base_component_id).id,
          "copied_from_id" => base.id
        )
      )
    end
  end

  def replay_matching_command!(payload)
    key = normalize_idempotency_key(@idempotency_key)
    digest = payload_digest(payload)
    lock_idempotency_slot!(COMMAND_NAME, key)
    existing = AgencyCommandIdempotencyKey.where(
      agency: @agency,
      command_name: COMMAND_NAME,
      idempotency_key: key
    ).lock.first
    return nil unless existing
    unless existing.payload_digest == digest
      raise Error.new("That idempotency key was already used for different input.", code: :conflict)
    end

    Result.new(
      status: :replayed,
      record: SupplierCostDefinition.find(existing.result_record_id)
    )
  end

  def claim_command!(payload, record)
    AgencyCommandIdempotencyKey.create!(
      agency: @agency,
      command_name: COMMAND_NAME,
      idempotency_key: normalize_idempotency_key(@idempotency_key),
      payload_digest: payload_digest(payload),
      result_record_type: SupplierCostDefinition.name,
      result_record_id: record.id
    )
  rescue ActiveRecord::RecordNotUnique
    raise Error.new("That idempotency key was already used for different input.", code: :conflict)
  end
end
