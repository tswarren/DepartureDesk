class CreateSupplierCostComponent < AgencyCommand
  include CostCommandSupport

  def initialize(agency:, actor:, definition:, attributes:, definition_lock_version:, base_links: nil, idempotency_key: nil)
    @agency, @actor, @definition = agency, actor, definition
    @attributes = attributes.to_h.with_indifferent_access
    @base_links = base_links || @attributes.delete(:base_links) || []
    @definition_lock_version = definition_lock_version
    @idempotency_key = idempotency_key || @attributes.delete(:idempotency_key)
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
        raise Error.new("Zero-cost definitions cannot contain components.", code: :invalid_state) if definition.zero_cost?
          attrs = normalize_component_attributes(
            @attributes, version: version, item: source.arrangement_item, currency: definition.currency
          )
        links = normalize_base_links(@base_links)
        idempotent_create!(
          command_name: self.class.name, idempotency_key: @idempotency_key,
          payload: attrs.merge(base_links: links, supplier_cost_definition_id: definition.id),
          result_class: SupplierCostComponent
        ) do
          ensure_current_lock_version!(definition, @definition_lock_version)
          components = definition.supplier_cost_components.order(:position, :id).lock.to_a
          component = definition.supplier_cost_components.create!(
            attrs.merge(owner_attributes_for(definition), position: components.size + 1)
          )
          replace_base_links!(definition, component, links)
          touch_definition_after_change!(definition)
          audit_cost!("supplier_arrangement.cost_component_created", arrangement, version, {
            "supplier_cost_source_id" => source.id, "supplier_cost_definition_id" => definition.id,
            "supplier_cost_component_id" => component.id, "economic_role" => component.economic_role,
            "calculation_kind" => component.calculation_kind, "position" => component.position
          })
          component
        end
      end
    end
  end
end
