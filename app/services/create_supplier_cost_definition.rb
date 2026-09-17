class CreateSupplierCostDefinition < AgencyCommand
  include CostCommandSupport

  def initialize(agency:, actor:, source:, attributes:, source_lock_version:, idempotency_key: nil)
    @agency, @actor, @source, @source_lock_version = agency, actor, source, source_lock_version
    @attributes = attributes.to_h.with_indifferent_access
    @idempotency_key = idempotency_key || @attributes.delete(:idempotency_key)
  end

  def call
    ensure_arrangement_actor!
    safely_command do
      ActiveRecord::Base.transaction do
        lock_authorized_arrangement_agency!
        departure, arrangement, version, contractor = cost_graph!(@source)
        source = lock_source!(version, @source)
        charging = locked_supplier!(source.charging_supplier_id)
        ensure_cost_ordinary_edit!(departure, arrangement, version, contractor, charging)
        stage = @attributes[:stage].to_s
        raise Error.new("Choose estimate or contracted.", code: :invalid) unless SupplierCostDefinition::STAGES.include?(stage)
        attrs = normalize_definition_attributes(@attributes, departure).merge(stage: stage)
        idempotent_create!(
          command_name: self.class.name, idempotency_key: @idempotency_key,
          payload: attrs.merge(supplier_cost_source_id: source.id),
          result_class: SupplierCostDefinition
        ) do
          ensure_current_lock_version!(source, @source_lock_version)
          definition = build_supplier_cost_definition_already_locked!(
            source: source,
            arrangement: arrangement,
            attributes: attrs
          )
          source.touch
          audit_cost!("supplier_arrangement.cost_definition_created", arrangement, version, {
            "supplier_cost_source_id" => source.id, "supplier_cost_definition_id" => definition.id,
            "stage" => definition.stage, "mode" => definition.mode, "status" => definition.status,
            "currency" => definition.currency
          })
          definition
        end
      end
    end
  end
end
