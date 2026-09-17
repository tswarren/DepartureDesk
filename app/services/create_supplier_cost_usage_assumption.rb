class CreateSupplierCostUsageAssumption < AgencyCommand
  include CostCommandSupport

  def initialize(agency:, actor:, arrangement_item:, attributes:, idempotency_key: nil)
    @agency, @actor, @item = agency, actor, arrangement_item
    @attributes = attributes.to_h.with_indifferent_access
    @idempotency_key = idempotency_key || @attributes.delete(:idempotency_key)
  end

  def call
    ensure_arrangement_actor!
    safely_command do
      ActiveRecord::Base.transaction do
        lock_authorized_arrangement_agency!
        departure, arrangement, version, contractor = cost_graph!(@item)
        ensure_cost_ordinary_edit!(departure, arrangement, version, contractor)
        item, occurrence, resource = lock_item_cost_context!(
          arrangement, version, item: @item, occurrence: @attributes[:service_occurrence_id],
          resource: @attributes[:supplier_resource_id]
        )
        attrs = assumption_attributes.merge(
          arrangement_item_id: item.id, service_occurrence_id: occurrence&.id,
          supplier_resource_id: resource&.id
        )
        idempotent_create!(
          command_name: self.class.name, idempotency_key: @idempotency_key,
          payload: attrs.merge(supplier_arrangement_version_id: version.id),
          result_class: SupplierCostUsageAssumption
        ) do
          assumption = version.supplier_cost_usage_assumptions.create!(
            attrs.merge(owner_attributes_for(version))
          )
          audit_cost!("supplier_arrangement.cost_usage_assumption_created", arrangement, version, {
            "supplier_cost_usage_assumption_id" => assumption.id
          }.merge(attrs.stringify_keys))
          assumption
        end
      end
    end
  end

  private

  def assumption_attributes
    {
      expected_resource_units: integer_or_nil(@attributes[:expected_resource_units], "Expected resource units"),
      expected_persons: integer_or_nil(@attributes[:expected_persons], "Expected persons"),
      expected_billable_nights: integer_or_nil(@attributes[:expected_billable_nights], "Expected billable nights")
    }
  end
end
