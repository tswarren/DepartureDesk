class CreateSupplierCostParticipantCategory < AgencyCommand
  include CostCommandSupport

  def initialize(agency:, actor:, arrangement_item:, version_lock_version:, attributes: nil, label: nil, idempotency_key: nil)
    @agency, @actor, @item = agency, actor, arrangement_item
    attrs = (attributes || {}).to_h.with_indifferent_access
    @label = label || attrs[:label]
    @version_lock_version = version_lock_version
    @idempotency_key = idempotency_key || attrs[:idempotency_key]
  end

  def call
    ensure_arrangement_actor!
    safely_command do
      ActiveRecord::Base.transaction do
        lock_authorized_arrangement_agency!
        departure, arrangement, version, contractor = cost_graph!(@item)
        ensure_cost_ordinary_edit!(departure, arrangement, version, contractor)
        item = lock_item_cost_context!(arrangement, version, item: @item).first
        label = normalize_text(@label, "Label", SupplierCostParticipantCategory::LABEL_LIMIT)
        idempotent_create!(
          command_name: self.class.name, idempotency_key: @idempotency_key,
          payload: { supplier_arrangement_version_id: version.id, arrangement_item_id: item.id, label: label },
          result_class: SupplierCostParticipantCategory
        ) do
          ensure_current_lock_version!(version, @version_lock_version)
          siblings = version.supplier_cost_participant_categories.where(arrangement_item: item).order(:position, :id).lock.to_a
          category = version.supplier_cost_participant_categories.create!(
            owner_attributes_for(version).merge(arrangement_item: item, label: label,
                                                position: siblings.map(&:position).max.to_i + 1)
          )
          bump_version!(version)
          audit_cost!("supplier_arrangement.cost_participant_category_created", arrangement, version, {
            "supplier_cost_participant_category_id" => category.id,
            "arrangement_item_id" => item.id, "label" => label, "position" => category.position
          })
          category
        end
      end
    end
  end
end
