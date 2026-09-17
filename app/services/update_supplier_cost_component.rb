class UpdateSupplierCostComponent < AgencyCommand
  include CostCommandSupport

  def initialize(agency:, actor:, component:, attributes:, lock_version:, definition_lock_version: nil, base_links: nil)
    @agency, @actor, @component, @lock_version = agency, actor, component, lock_version
    @attributes = attributes.to_h.with_indifferent_access
    @base_links_supplied = !base_links.nil? || @attributes.key?(:base_links)
    @base_links = base_links || @attributes.delete(:base_links) || []
    @definition_lock_version = definition_lock_version
  end

  def call
    ensure_arrangement_actor!
    safely_command do
      ActiveRecord::Base.transaction do
        lock_authorized_arrangement_agency!
        departure, arrangement, version, contractor = cost_graph!(@component)
        source = lock_source!(version, @component.supplier_cost_definition.supplier_cost_source)
        charging = locked_supplier!(source.charging_supplier_id)
        ensure_cost_ordinary_edit!(departure, arrangement, version, contractor, charging)
        definition = lock_definition!(source, @component.supplier_cost_definition)
        component = lock_component!(definition, @component)
        ensure_current_lock_version!(component, @lock_version)
        component_fields = %i[
          label economic_role calculation_kind amount_minor_units rate minimum_minor_units
          minimum_quantity quantity_basis participant_category_id occupancy_position_from
          occupancy_position_to percentage_treatment pass_through
        ]
        current = component_fields.to_h { |field| [ field, component.public_send(field) ] }
        attrs = normalize_component_attributes(current.merge(@attributes), version: version, item: source.arrangement_item)
        links = normalize_base_links(@base_links)
        current_links = component.supplier_cost_component_bases.order(:position).map do |base|
          { base_component_id: base.base_component_id, direction: base.direction, position: base.position }
        end
        links_changed = @base_links_supplied && links != current_links
        return Result.new(status: :noop, record: component) if same_values?(component, attrs) && !links_changed
        ensure_current_lock_version!(definition, @definition_lock_version) if links_changed
        component.update!(attrs)
        replace_base_links!(definition, component, links) if links_changed
        touch_definition_after_change!(definition) if definition.forecast_ready? || links_changed
        audit_cost!("supplier_arrangement.cost_component_updated", arrangement, version, {
          "supplier_cost_source_id" => source.id, "supplier_cost_definition_id" => definition.id,
          "supplier_cost_component_id" => component.id, "changed_fields" => changed_fields(component, attrs),
          "base_links_changed" => links_changed, "economic_role" => component.economic_role,
          "calculation_kind" => component.calculation_kind
        })
        Result.new(status: :updated, record: component)
      end
    end
  end
end
