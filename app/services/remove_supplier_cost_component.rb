class RemoveSupplierCostComponent < AgencyCommand
  include CostCommandSupport

  def initialize(agency:, actor:, component:, definition_lock_version:, dependent_base_link_ids: [])
    @agency, @actor, @component = agency, actor, component
    @definition_lock_version, @base_link_ids = definition_lock_version, dependent_base_link_ids
  end

  def call
    ensure_arrangement_actor!
    safely_command do
      ActiveRecord::Base.transaction do
        lock_authorized_arrangement_agency!
        departure, arrangement, version, = cost_graph!(@component)
        ensure_cost_cleanup_edit!(departure, arrangement, version)
        source = lock_source!(version, @component.supplier_cost_definition.supplier_cost_source)
        definition = lock_definition!(source, @component.supplier_cost_definition)
        ensure_current_lock_version!(definition, @definition_lock_version)
        component = lock_component!(definition, @component)
        dependent = component.dependent_base_links.order(:id).lock.to_a
        submitted = Array(@base_link_ids).map { |id| required_uuid(id, "Base link") }
        links = dependent.select { |link| submitted.include?(link.id) }
        unless links.size == submitted.uniq.size
          raise ActiveRecord::RecordNotFound
        end
        links.each(&:destroy!)
        if component.dependent_base_links.exists?
          raise Error.new("Remove later component base links before removing this component.", code: :dependency_exists)
        end
        details = {
          "supplier_cost_source_id" => source.id, "supplier_cost_definition_id" => definition.id,
          "supplier_cost_component_id" => component.id, "economic_role" => component.economic_role,
          "calculation_kind" => component.calculation_kind, "position" => component.position
        }
        component.supplier_cost_component_bases.each(&:destroy!)
        component.destroy!
        remaining = definition.supplier_cost_components.order(:position, :id).lock.to_a
        remaining.each_with_index { |entry, index| entry.update!(position: index + 1) }
        touch_definition_after_change!(definition)
        audit_cost!("supplier_arrangement.cost_component_removed", arrangement, version, details)
        Result.new(status: :updated, record: definition)
      end
    end
  end
end
