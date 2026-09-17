class ReorderSupplierCostParticipantCategories < AgencyCommand
  include CostCommandSupport

  def initialize(agency:, actor:, arrangement_item:, supplier_cost_participant_category_ids:, version_lock_version:)
    @agency, @actor, @item = agency, actor, arrangement_item
    @ids, @version_lock_version = supplier_cost_participant_category_ids, version_lock_version
  end

  def call
    ensure_arrangement_actor!
    safely_command do
      ActiveRecord::Base.transaction do
        lock_authorized_arrangement_agency!
        departure, arrangement, version, contractor = cost_graph!(@item)
        ensure_cost_ordinary_edit!(departure, arrangement, version, contractor)
        ensure_current_lock_version!(version, @version_lock_version)
        item = lock_item_cost_context!(arrangement, version, item: @item).first
        categories = version.supplier_cost_participant_categories.where(arrangement_item: item).order(:position, :id).lock.to_a
        ids = exact_permutation!(@ids, categories.map(&:id), "Participant category")
        old = categories.to_h { |category| [ category.id, category.position ] }
        by_id = categories.index_by(&:id)
        ids.each_with_index { |id, index| by_id.fetch(id).update!(position: index + 1) }
        ActiveRecord::Base.connection.execute("SET CONSTRAINTS supplier_cost_categories_position_unique IMMEDIATE")
        bump_version!(version)
        audit_cost!("supplier_arrangement.cost_participant_categories_reordered", arrangement, version, {
          "arrangement_item_id" => item.id, "supplier_cost_participant_category_ids" => ids,
          "old_positions" => old, "new_positions" => ids.each_with_index.to_h { |id, i| [ id, i + 1 ] }
        })
        Result.new(status: :updated, record: item)
      end
    end
  end
end
