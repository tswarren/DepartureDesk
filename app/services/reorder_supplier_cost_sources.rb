class ReorderSupplierCostSources < AgencyCommand
  include CostCommandSupport

  def initialize(agency:, actor:, arrangement:, supplier_cost_source_ids:, version_lock_version:, arrangement_item: nil)
    @agency, @actor, @arrangement = agency, actor, arrangement
    @ids, @version_lock_version, @item = supplier_cost_source_ids, version_lock_version, arrangement_item
  end

  def call
    ensure_arrangement_actor!
    safely_command do
      ActiveRecord::Base.transaction do
        lock_authorized_arrangement_agency!
        departure, arrangement, version, contractor = cost_graph!(@arrangement)
        ensure_cost_ordinary_edit!(departure, arrangement, version, contractor)
        ensure_current_lock_version!(version, @version_lock_version)
        item = @item && lock_item_cost_context!(arrangement, version, item: @item).first
        sources = version.supplier_cost_sources.where(arrangement_item_id: item&.id).order(:position, :id).lock.to_a
        ids = exact_permutation!(@ids, sources.map(&:id), "Cost source")
        old = sources.to_h { |source| [ source.id, source.position ] }
        by_id = sources.index_by(&:id)
        ids.each_with_index { |id, index| by_id.fetch(id).update!(position: index + 1) }
        ActiveRecord::Base.connection.execute("SET CONSTRAINTS supplier_cost_sources_position_unique IMMEDIATE")
        bump_version!(version)
        audit_cost!("supplier_arrangement.cost_sources_reordered", arrangement, version, {
          "arrangement_item_id" => item&.id, "supplier_cost_source_ids" => ids,
          "old_positions" => old, "new_positions" => ids.each_with_index.to_h { |id, i| [ id, i + 1 ] }
        })
        Result.new(status: :updated, record: arrangement)
      end
    end
  end
end
