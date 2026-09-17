class ReorderSupplierCostComponents < AgencyCommand
  include CostCommandSupport

  def initialize(agency:, actor:, definition:, supplier_cost_component_ids:, definition_lock_version:)
    @agency, @actor, @definition = agency, actor, definition
    @ids, @definition_lock_version = supplier_cost_component_ids, definition_lock_version
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
        ensure_current_lock_version!(definition, @definition_lock_version)
        components = definition.supplier_cost_components.order(:position, :id).lock.to_a
        ids = exact_permutation!(@ids, components.map(&:id), "Cost component")
        proposed = ids.each_with_index.to_h
        SupplierCostComponentBase.where(supplier_cost_definition: definition).lock.each do |link|
          unless proposed.fetch(link.base_component_id) < proposed.fetch(link.supplier_cost_component_id)
            raise Error.new("A component cannot be ordered before one of its bases.", code: :invalid)
          end
        end
        old = components.to_h { |component| [ component.id, component.position ] }
        offset = components.size + 1
        # Move dependents to temporary positions before bases so the forward-base
        # trigger never sees an earlier base behind a still-unmoved dependent.
        components.sort_by { |component| -component.position }.each do |component|
          component.update!(position: component.position + offset)
        end
        by_id = components.index_by(&:id)
        ids.each_with_index { |id, index| by_id.fetch(id).update!(position: index + 1) }
        touch_definition_after_change!(definition)
        audit_cost!("supplier_arrangement.cost_components_reordered", arrangement, version, {
          "supplier_cost_source_id" => source.id, "supplier_cost_definition_id" => definition.id,
          "supplier_cost_component_ids" => ids, "old_positions" => old,
          "new_positions" => ids.each_with_index.to_h { |id, i| [ id, i + 1 ] }
        })
        Result.new(status: :updated, record: definition)
      end
    end
  end
end
